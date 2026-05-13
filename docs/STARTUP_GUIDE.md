# Cloud Data Platform — Startup & Operations Guide

End-to-end walkthrough: from a fresh clone to a running medallion pipeline
(Bronze → Silver → Gold) on EKS, with secure public access via Cloudflare
Tunnel, and a clean stop / restart cycle.

> Target environment: **`dev`** in AWS `us-east-1`, EKS cluster `dataplatform-dev`,
> Terraform state on Cloudflare R2.

---

## 0. Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| `aws` CLI | ≥ 2.13 | `aws configure --profile dataplatform-dev` (or `AWS_PROFILE`) |
| `terraform` | ≥ 1.6 | |
| `kubectl` | ≥ 1.30 | |
| `helm` | ≥ 3.14 | |
| `docker` | ≥ 24 | only when building the Spark image |
| `jq`, `openssl`, `sed` | any | shell helpers |
| WSL or Linux | — | scripts assume bash + LF line endings |

Accounts:
- **AWS** with admin on the target account (creates VPC, EKS, IAM, ECR, Lambda).
- **Cloudflare** with R2 (state) and Zero Trust (Tunnel) — only required for Phase 6
  (public DNS) and the remote backend.

Environment variables expected by scripts (you can put them in a `.envrc`):

```bash
export AWS_PROFILE=dataplatform-dev
export TF_STATE_BUCKET=dataplatform-tfstate-dev
export CF_ACCOUNT_ID=<cloudflare-account-id>
export CF_R2_ACCESS_KEY_ID=<r2-token-id>
export CF_R2_SECRET_ACCESS_KEY=<r2-token-secret>
```

---

## 1. One-time bootstrap (R2 backend, only first time ever)

Creates the R2 bucket that stores Terraform state.

```bash
./scripts/tf-init-local.sh terraform/bootstrap   # init the bootstrap module
terraform -chdir=terraform/bootstrap apply
```

You only re-run this if the R2 bucket is destroyed.

---

## 2. Configure `terraform.tfvars`

```bash
cp terraform/environments/dev/terraform.tfvars.example terraform/environments/dev/terraform.tfvars
```

Required edits:

```hcl
cluster_endpoint_public_access_cidrs = ["<YOUR-PUBLIC-IP>/32"]   # curl https://api.ipify.org
node_group_compute_desired_size      = 1
node_group_compute_max_size          = 4   # autoscaler can grow up to 4
node_group_stateful_desired_size     = 2
```

> If your public IP changes, update this file and re-run `terraform apply` —
> kubectl will otherwise time out on the EKS endpoint.

---

## 3. Apply Phase 1 + Phase 2 in one shot (fast track)

```bash
./scripts/fasttrack-infra.sh --auto-approve --with-phase2
```

What this does:
1. `terraform apply` → VPC, EKS, IRSA, ECR, KMS, Lambda scaling, EventBridge.
2. Configures `kubeconfig` (`aws eks update-kubeconfig`).
3. Applies Phase 1 manifests (namespaces, network policies, storage class).
4. Installs **Cluster Autoscaler** (lets `compute-ng` scale `1 → 4`).
5. Generates Phase 2 secrets (`prepare-phase2-secrets.sh`).
6. Installs Phase 2: cert-manager, MinIO Operator + Tenant, CNPG (`pg-source` +
   `pg-hms`), Hive Metastore.

Verify:

```bash
kubectl get nodes -L workload
kubectl -n platform-security    get pod
kubectl -n platform-storage     get pod,svc,pvc
kubectl -n platform-metastore   get deploy
kubectl -n kube-system          get deploy cluster-autoscaler
```

---

## 4. Phase 3 — Kafka, Debezium CDC, NiFi

```bash
./scripts/bootstrap-phase3.sh
```

What it does:
- Installs the Strimzi operator.
- Creates a dev Kafka cluster (1 broker + 1 ZK, small PVCs). Set
  `KAFKA_VARIANT=prod` for the 3-broker spec-aligned variant.
- Creates KafkaTopics (`bronze.*`, `cdc.pg.*`).
- Mirrors `pg-source-app-secret` from `platform-storage` → `platform-ingestion`
  so KafkaConnect can read it via Strimzi external configuration.
- Deploys `KafkaConnect` (Debezium 2.7) + a `KafkaConnector` for PostgreSQL CDC
  using the `debezium_pub` publication that CNPG created at first init.
- Deploys NiFi for ad-hoc ingestion.

Verify:

```bash
kubectl -n platform-ingestion get kafka,kafkatopic,kafkaconnect,kafkaconnector
kubectl -n platform-ingestion logs deploy/platform-connect-connect | grep -i 'pg-source-cdc'
```

---

## 5. Build the `spark-iceberg:3.5.0` image and push to ECR

The Spark Operator + dbt jobs all run from the same image (Iceberg runtime,
hadoop-aws, dbt-spark, embedded `/opt/jobs/` and `/opt/dbt/`).

```bash
./scripts/build-spark-image.sh
```

Auto-detects the ECR registry URL from `terraform output -raw ecr_registry_url`,
builds the image from `docker/spark-iceberg/`, and pushes
`<account>.dkr.ecr.us-east-1.amazonaws.com/dataplatform/spark-iceberg:3.5.0`.

Verify:

```bash
aws ecr describe-images --repository-name dataplatform/spark-iceberg --query 'imageDetails[].imageTags'
```

---

## 6. Phase 4 — Spark Operator + Airflow + dbt

```bash
./scripts/bootstrap-phase4.sh
```

What it does:
1. Installs the Kubeflow Spark Operator in `platform-compute`.
2. Renders SparkApplications by replacing `REPLACE_ME_REGISTRY` with the real
   ECR URL (output of `terraform output -raw ecr_registry_url`) and writes them
   to `bootstrap/phase-4/manifests/spark-jobs/.rendered/`.
3. Creates the CNPG cluster used by Airflow metadata DB (`pg-airflow`).
4. Calls `prepare-airflow-dags.sh` → builds the `airflow-dags` ConfigMap from
   `dags/*.py` + the rendered Spark manifests.
5. Installs Airflow (KubernetesExecutor, external CNPG metadata) with
   `airflow-dags` mounted at `/opt/airflow/dags`.
6. Applies the **Airflow → Spark** RBAC binding (`airflow-spark-rolebinding.yaml`)
   so the Airflow worker SA can submit `SparkApplication` CRDs in
   `platform-compute`.

DAGs shipped:

| DAG | Schedule | What it submits |
|-----|----------|-----------------|
| `bronze_streaming` | `@once` | `bronze-iceberg-writer` (Kafka → Iceberg Bronze, long-running) |
| `bronze_files_daily` | `@daily 02:00` | `file-to-iceberg-ingestion` (XLSX/CSV → Iceberg Bronze) |
| `silver_gold_dbt` | `@hourly` | `dbt-run` (Iceberg → Silver/Gold via dbt-spark) |

Verify:

```bash
kubectl -n platform-compute   get sparkapplications
kubectl -n platform-orchestr  get pod
kubectl -n platform-orchestr  port-forward svc/airflow-webserver 8080:8080
# open http://localhost:8080  (admin/admin by default — change in airflow-values.yaml for real use)
```

To refresh DAGs after editing `dags/*.py`:

```bash
./scripts/prepare-airflow-dags.sh   # rebuilds the ConfigMap; scheduler picks it up in ~30s
```

---

## 7. Phase 5 — Dremio Nautilus

```bash
./scripts/bootstrap-phase5.sh
```

Then add the Hive Metastore + MinIO source in the Dremio UI (or via REST):

```bash
kubectl -n platform-query port-forward svc/dremio-client 9047:9047
# open http://localhost:9047 → Sources → Add Source → Hive
#   Hostname: hive-metastore.platform-metastore.svc.cluster.local
#   Port:     9083
#   Advanced → Connection Properties:
#     fs.s3a.endpoint=http://lakehouse-tenant-hl.platform-storage.svc.cluster.local:9000
#     fs.s3a.access.key / fs.s3a.secret.key (from minio-admin-secret)
#     fs.s3a.path.style.access=true
```

Or apply the JSON template:

```bash
DREMIO_TOKEN=...   # from /apiv2/login
curl -X POST -H "Authorization: _dremio${DREMIO_TOKEN}" -H 'Content-Type: application/json' \
  --data @bootstrap/phase-5/manifests/dremio/source-hive.json \
  http://localhost:9047/apiv3/catalog
```

---

## 8. Phase 6 — Cloudflare Zero Trust Tunnel

In the Cloudflare dashboard:

1. **Zero Trust → Networks → Tunnels → Create a tunnel** (name e.g. `dataplatform-dev`).
   Copy the Tunnel UUID and the credentials JSON (`AccountTag`, `TunnelSecret`,
   `TunnelID`).
2. **My Profile → API Tokens** → create a token with:
   - `Account.Cloudflare Tunnel: Edit`
   - `Zone.DNS: Edit` (on the zone you'll publish to).

Then run the interactive renderer:

```bash
./scripts/configure-cloudflare.sh
```

It writes the real values into:

- `bootstrap/phase-6/manifests/secrets/cloudflare-api-token.yaml`
- `bootstrap/phase-6/manifests/secrets/cloudflare-tunnel-credentials.yaml`
- `bootstrap/phase-6/helm/cloudflare-operator-values.yaml`
- `bootstrap/phase-6/manifests/cluster-tunnel/cluster-tunnel.yaml`
- `bootstrap/phase-6/manifests/tunnel-bindings/*.yaml`

Then deploy:

```bash
./scripts/bootstrap-phase6.sh
```

Public hostnames (defaults):

| Service | Hostname |
|---------|---------|
| Airflow | `airflow.dataplatform.<your-zone>` |
| Dremio | `dremio.dataplatform.<your-zone>` |
| Grafana | `grafana.dataplatform.<your-zone>` |
| NiFi | `nifi.dataplatform.<your-zone>` |

Verify:

```bash
kubectl -n platform-security get cf clustertunnel,tunnelbinding
dig airflow.dataplatform.<your-zone>
```

---

## 9. Phase 7 — Observability

```bash
./scripts/bootstrap-phase7.sh
```

Installs Prometheus + Grafana, Fluent Bit (logs → OpenObserve), OpenObserve,
plus ServiceMonitors for Kafka, MinIO, CNPG, Spark Operator, Airflow, Dremio.

Verify:

```bash
kubectl -n platform-observ port-forward svc/kube-prometheus-stack-grafana 3000:80
# user: admin  password: kubectl -n platform-observ get secret kube-prometheus-stack-grafana -o jsonpath='{.data.admin-password}' | base64 -d
```

---

## 10. Phase 9 — Lambda scheduled scaling (optional)

Already provisioned by Phase 1 (`terraform/modules/lambda-scaling`). Defaults:

- **Mon–Fri 08:00 UTC** → scale `compute-ng` from 0 → desired = 1.
- **Mon–Fri 20:00 UTC** → scale back to 0.

Tune via `lambda_scaling_*` variables in `terraform.tfvars`.

---

## 11. Phase 10 — ArgoCD GitOps (optional)

Only if you want pull-based deployment instead of running the bootstrap scripts.

```bash
./scripts/bootstrap-phase10.sh
kubectl -n platform-gitops port-forward svc/argocd-server 8443:443
# password: kubectl -n platform-gitops get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

The Application CRDs in `bootstrap/phase-10/manifests/applications/` point at
this same repo; for a true GitOps workflow, push the `bootstrap/` tree to a
dedicated repo and update the `repoURL` field.

---

## 12. End-to-end medallion smoke test

After Phases 2 + 3 + 4 are up:

```bash
# 1. Insert sample rows into pg-source (Debezium will publish them to cdc.pg.public.agency_budget)
kubectl -n platform-storage exec -it pg-source-cluster-1 -- psql -U nifi_user source_db -c \
  "CREATE TABLE IF NOT EXISTS public.agency_budget (id serial primary key, agency text, amount numeric, ts timestamp default now());
   INSERT INTO public.agency_budget (agency, amount) VALUES ('agency-A', 1000), ('agency-B', 2500);"

# 2. Trigger the Bronze streaming DAG (it submits the SparkApplication that consumes cdc.pg.* into Iceberg)
kubectl -n platform-orchestr exec deploy/airflow-scheduler -- airflow dags unpause bronze_streaming

# 3. Watch the SparkApplication
kubectl -n platform-compute get sparkapplications -w

# 4. Trigger silver/gold dbt
kubectl -n platform-orchestr exec deploy/airflow-scheduler -- airflow dags trigger silver_gold_dbt

# 5. Query Gold from Dremio (after adding the Hive source) — see Phase 5 step.
```

Expected Iceberg tables once the pipeline runs:
- `lakehouse.bronze.cdc_pg_public_agency_budget`
- `lakehouse.silver.stg_agency_budget`
- `lakehouse.gold.agg_monthly_budget`

---

## 13. Stop / restart cycle

### Tear everything down (avoids charges)

```bash
./scripts/teardown-infra.sh
```

What it does **in order**:
1. Helm-uninstalls Phases 10 → 7 → 6 → 5 → 4 → 3 → 2.
2. Deletes any remaining `LoadBalancer` Services (release the ELBs).
3. Deletes all PVCs in `platform-*` (release the EBS volumes).
4. Deletes the platform namespaces.
5. `terraform destroy` of the dev environment.

What it **preserves**:
- `terraform/bootstrap` (R2 bucket + KMS keys).
- ECR images (so you don't need to rebuild Spark on the next cycle).
- Cloudflare account / tunnel credentials.

### Bring it back up

```bash
./scripts/fasttrack-infra.sh --auto-approve --with-all
# then:
./scripts/build-spark-image.sh   # only if you cleared ECR
./scripts/configure-cloudflare.sh   # only if you regenerated the tunnel
./scripts/bootstrap-phase6.sh
```

The whole cycle (destroy → apply → all phases) takes ~25–35 min.

---

## 14. Troubleshooting

| Symptom | Fix |
|---------|-----|
| `kubectl` times out on EKS endpoint | Your public IP changed. Update `cluster_endpoint_public_access_cidrs` in `terraform.tfvars` and re-run `terraform apply`. |
| cert-manager pods `Pending` | `compute-ng` is at 0 nodes. Either bump `node_group_compute_desired_size = 1`, or wait for the autoscaler (it scales up only when an unschedulable pod is detected on the right node selector). |
| `SparkApplication` stuck `SUBMITTED` | Image not in ECR or RBAC missing. Run `./scripts/build-spark-image.sh` and `kubectl -n platform-compute describe sparkapp <name>`. |
| Airflow worker `Forbidden` creating SparkApplication | The `airflow-spark-launcher` RoleBinding wasn't applied. Re-run `kubectl apply -f bootstrap/phase-4/manifests/spark-rbac/airflow-spark-rolebinding.yaml`. |
| Debezium connector `Failed to create replication slot` | The `debezium_pub` publication is missing. Connect to `pg-source-cluster-1` and run `CREATE PUBLICATION debezium_pub FOR ALL TABLES;`. The CNPG `postInitApplicationSQL` does this automatically on first init only. |
| Cloudflare tunnel `Unauthorized` | API token missing the `Cloudflare Tunnel: Edit` permission, or wrong `accountId` in the operator values. |
| Airflow DAGs not visible | Run `./scripts/prepare-airflow-dags.sh` after editing — the ConfigMap must be regenerated. The scheduler refreshes the DagBag every 30 s. |
| Cluster Autoscaler not scaling up | `kubectl -n kube-system logs deploy/cluster-autoscaler` — usually missing IRSA tags on ASGs (re-apply Terraform after the EKS module update). |

---

## 15. Reference: what runs where

| Namespace | Purpose | Node group |
|-----------|---------|-----------|
| `kube-system` | EBS CSI, autoscaler, AWS LB controller | stateful (autoscaler), default |
| `platform-security` | cert-manager, External Secrets, Cloudflare Operator | stateful |
| `platform-storage` | MinIO Tenant, CNPG `pg-source` | stateful |
| `platform-metastore` | Hive Metastore + CNPG `pg-hms` | stateful |
| `platform-ingestion` | Strimzi, Kafka, Connect/Debezium, NiFi | stateful (brokers), compute (NiFi) |
| `platform-compute` | Spark Operator, SparkApplications | compute |
| `platform-orchestr` | Airflow + CNPG `pg-airflow` | compute |
| `platform-query` | Dremio coordinator/executors | compute |
| `platform-observ` | kube-prometheus-stack, OpenObserve, Fluent Bit | compute |
| `platform-gitops` | ArgoCD (optional) | compute |

---

## 16. What you need to do *outside* the repo

These items can't be automated from Terraform:

- **Cloudflare**: create the tunnel + API token in the Zero Trust dashboard
  (one-time). The script `configure-cloudflare.sh` then injects them.
- **Airflow DAGs repo (optional)**: if you want GitSync, push `dags/` to a
  GitHub repo `dataplatform-airflow-dags` and flip the relevant block in
  `bootstrap/phase-4/helm/airflow-values.yaml`.
- **GitOps repo (optional, Phase 10 only)**: same idea — push `bootstrap/` to a
  dedicated repo and update `repoURL` in the ArgoCD `Application` CRDs.
- **Public IP rotation**: when your home IP changes, update
  `cluster_endpoint_public_access_cidrs` and re-apply Terraform.
