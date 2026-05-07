# Phase checkpoints — when to run what

This file is the **operational contract** between the three PDF specs (`docs/specs/`) and the repo. Use it so you do not start Phase 2 or 3 before the platform is ready.

## Phase 0 — Accounts & GitHub (one-time)

- [ ] AWS account + CLI profile (e.g. `dataplatform-admin`).
- [ ] Cloudflare: R2 state bucket exists; **S3 API** keys for Terraform backend created; `TF_STATE_BUCKET`, `CF_R2_*`, `CF_ACCOUNT_ID` in GitHub.
- [ ] `terraform/bootstrap` applied: `github_actions_role_arn` → secret `AWS_GH_ACTIONS_ROLE_ARN`.
- [ ] GitHub Environment **`dev`** with required reviewer (gates `terraform apply`).

## Phase 1 — Landing zone (Terraform + K8s baseline)

**Done in code:** `terraform/environments/dev`, `bootstrap/namespaces|network-policies|resource-quotas|storage-classes`, `scripts/bootstrap-cluster.sh`, CI workflows.

**You are ready for the next step when:**

- [ ] `terraform apply` for **dev** completed (VPC, EKS, KMS, IAM).
- [ ] `aws eks update-kubeconfig` works; `kubectl get nodes` shows Ready nodes.
- [ ] `./scripts/bootstrap-cluster.sh` ran successfully (idempotent).
- [ ] `kubectl get ns -l app.kubernetes.io/part-of=dataplatform` lists the **9 spec namespaces** (`platform-ingestion`, `platform-storage`, `platform-metastore`, `platform-compute`, `platform-orchestr`, `platform-serving`, `platform-monitoring`, `platform-logging`, `platform-security`). cert-manager runs **inside `platform-security`** per `Specifications_Doc_for_PFE.pdf` §2.2.

**Stop here** until all boxes are checked. Phase 2 installs operators that assume Phase 1 namespaces and storage class **`gp3`**.

---

## Phase 2 — Storage & catalog (MinIO, CNPG, Hive)

**Aligned with:** `Doc (1).pdf` Phase 2–3, `Specifications_Doc_for_PFE.pdf` (MinIO, Hive), pedagogical guide.

**Start Phase 2 only when Phase 1 checkpoint above is complete.**

1. Generate secrets (random values, **gitignored**):

   ```bash
   chmod +x scripts/prepare-phase2-secrets.sh scripts/bootstrap-phase2.sh
   ./scripts/prepare-phase2-secrets.sh
   ```

   Or copy/edit manually from `*.example.yaml` per `bootstrap/phase-2/manifests/secrets/README.md`.

2. Run:

   ```bash
   ./scripts/bootstrap-phase2.sh
   ```

The script installs **cert-manager** first (TLS prerequisite per spec), then MinIO operator/tenant, CNPG, PostgreSQL clusters, Hive metastore DB + config.

**Phase 2 is “good enough” for defense when:** pods are Running in `platform-storage`, `platform-metastore`; MinIO tenant reachable inside cluster; CNPG clusters Ready.

---

## Phase 3 — Ingestion (Kafka, KafkaConnect/Debezium, NiFi)

**Aligned with:** `Specifications_Doc_for_PFE.pdf` §3.4 + §4.

**Start Phase 3 only when** Phase 2 checkpoint satisfied (`platform-ingestion` usable, `pg-source-cluster` Ready for the Debezium connector).

```bash
./scripts/bootstrap-phase3.sh                  # dev variant: 1 broker + 1 ZK
KAFKA_VARIANT=prod ./scripts/bootstrap-phase3.sh   # 3 brokers + 3 ZK
```

Topics applied: `bronze.pg.public.agency-budget`, `bronze.pg.public.clients`, `cdc.pg.public.agency-budget`. KafkaConnect ships Debezium image with a `KafkaConnector` against `pg-source-cluster`. NiFi UI flows are still procedural (capture screenshots for the jury).

---

## Phase 4 — Compute (Spark Operator + Airflow + dbt)

**Aligned with:** `Specifications_Doc_for_PFE.pdf` §3.5, §3.6, §6.1.

**Pre-requisites:**

- [ ] Phase 2 stable; Hive Metastore reachable on `hive-metastore.platform-metastore:9083`.
- [ ] Image `spark-iceberg:3.5.0` built (`iceberg-spark-runtime-3.5_2.12:1.4.2`, `hadoop-aws`, `dbt-spark`) and pushed to ECR.

```bash
./scripts/prepare-phase4-secrets.sh
./scripts/bootstrap-phase4.sh
```

Verify: `kubectl -n platform-compute get sparkapplications`, `kubectl -n platform-orchestr get pods` (airflow webserver + scheduler Running).

---

## Phase 5 — Serving (Dremio)

```bash
./scripts/bootstrap-phase5.sh
kubectl -n platform-serving port-forward svc/dremio-client 9047:9047
# Add Hive source via REST: bootstrap/phase-5/manifests/dremio/source-hive.json
```

---

## Phase 6 — Exposure (Cloudflare Zero Trust)

**Pre-requisites:** Cloudflare tunnel created in dashboard; API token + tunnel credentials filled in `bootstrap/phase-6/manifests/secrets/*.yaml`.

```bash
./scripts/bootstrap-phase6.sh
```

Verify: `kubectl -n platform-security get clustertunnel,tunnelbinding -A`, then test SSO at `https://airflow.dataplatform.<your-zone>`.

---

## Phase 7 — Observability (Prometheus, Grafana, Fluent Bit, OpenObserve)

```bash
./scripts/bootstrap-phase7.sh
kubectl -n platform-monitoring port-forward svc/monitoring-grafana 3000:80
kubectl -n platform-logging port-forward svc/openobserve 5080:5080
```

ServiceMonitors / PodMonitors are pre-wired for Spark Operator, MinIO Tenant, CNPG (PG metrics), Strimzi Kafka.

---

## Phase 9 — Cost optimisation (Lambda scaling)

```hcl
# terraform/environments/dev/terraform.tfvars
lambda_scaling_enabled = true
```

```bash
terraform -chdir=terraform/environments/dev apply
aws lambda invoke --function-name dataplatform-dev-eks-scaler \
  --payload '{"action":"scale_down"}' /tmp/out.json && cat /tmp/out.json
```

---

## Phase 10 — ArgoCD (optional)

```bash
./scripts/bootstrap-phase10.sh
kubectl -n platform-security get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d ; echo
```

---

*Last updated together with `MEMORY.md` checkpoints.*
