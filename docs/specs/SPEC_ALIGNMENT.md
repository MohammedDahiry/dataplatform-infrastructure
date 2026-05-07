# Spec alignment — Cloud Data Platform (PFE 2025–2026)

This matrix ties the **official PDF specifications** in `docs/specs/` to **artifacts in this repository**. Use it for jury traceability (“exigence → preuve dans le dépôt”).

**Sources**

| Document | Role |
|----------|------|
| `Specifications_Doc_for_PFE.pdf` | Architecture, stack (MinIO, Iceberg, Hive, Terraform, Ansible, CI/CD, phased MVP). |
| `cloud_data_platform_guide (1).pdf` | Pedagogical guide (bootstrap, VPC, phases, lexique). |
| `Doc (1).pdf` | **Full Implementation Guide** — phased build (Phases 1–10): VPC/EKS, MinIO/Hive, Kafka/NiFi, Spark/dbt/Airflow, Dremio/Power BI, Cloudflare Zero Trust, Prometheus/Grafana, CI/CD, Lambda scheduling, optional ArgoCD. |

---

## MVP phased delivery (spec §14.1 style)

| Phase (guide) | Scope | Repo status |
|---------------|--------|-------------|
| **1** | VPC, EKS, namespaces, RBAC, storage class, network baseline | **Implemented:** `terraform/modules/{vpc,kms,iam,eks}`, `terraform/environments/dev`, `bootstrap/*`, `scripts/bootstrap-cluster.sh`, `.github/workflows/terraform-*.yml`. |
| **2** | MinIO Operator + Tenant, CNPG PostgreSQL, Hive Metastore, cert-manager | **Implemented:** `scripts/bootstrap-phase2.sh` installs **cert-manager first into `platform-security`** (per spec §2.2), then MinIO → CNPG → Hive (`bootstrap/phase-2/`). **Gap:** production-grade Hive vs Bitnami Postgres-only baseline; tighten TLS/Issuers for real certs. |
| **3** | Strimzi Kafka, NiFi, CDC | **Implemented:** `bootstrap/phase-3/` adds `KAFKA_VARIANT=dev|prod` (single-broker dev variant, 3+3 prod variant), `KafkaTopic` for medallion (`bronze.*`, `cdc.*`), `KafkaConnect` + Debezium `KafkaConnector` against `pg-source-cluster`, and the NiFi StatefulSet. Driver: `scripts/bootstrap-phase3.sh`. |
| **4** | Spark Operator, dbt, Airflow, Iceberg jobs | **Implemented:** `bootstrap/phase-4/` ships `spark-operator-values.yaml`, `spark-rbac/`, two `SparkApplication` examples (streaming Bronze + file ingestion), Airflow Helm values (KubernetesExecutor + external CNPG), `pg-airflow` CNPG cluster, and a `dbt-spark` project skeleton (`dbt/` with sources + silver/gold models). Driver: `scripts/bootstrap-phase4.sh` + `scripts/prepare-phase4-secrets.sh`. |
| **5** | Dremio, Power BI | **Implemented:** `bootstrap/phase-5/` (Helm values for Dremio coordinator/executor, dist-storage on MinIO, Hive source JSON for the Dremio REST API). Driver: `scripts/bootstrap-phase5.sh`. Power BI ODBC/Arrow Flight integration documented (configuration only, no infra). |
| **6** | Cloudflare Zero Trust (Tunnel / operator) | **Implemented:** `bootstrap/phase-6/` (Cloudflare Operator Helm values into `platform-security`, `ClusterTunnel`, `TunnelBinding` examples for Airflow/Dremio/Grafana/NiFi, gitignored secrets templates). Driver: `scripts/bootstrap-phase6.sh`. |
| **7** | Prometheus, Grafana, OpenObserve, Fluent Bit | **Implemented:** `bootstrap/phase-7/` (kube-prometheus-stack, OpenObserve, Fluent Bit DaemonSet shipping logs to OpenObserve, `ServiceMonitor`/`PodMonitor` for Spark, MinIO, CNPG, Strimzi). Driver: `scripts/bootstrap-phase7.sh`. |
| **8** | GitHub Actions CI/CD, OIDC | **Implemented** for Terraform plan/apply. **Gap:** spec also mentions Ansible + broader pipeline — optional extensions. |
| **9** | Lambda node scheduling (cost) | **Implemented:** Terraform module `terraform/modules/lambda-scaling` (Python Lambda + EventBridge cron up/down, scoped IAM `eks:Update/Describe/ListNodegroup`). Wired into `terraform/environments/dev` behind `lambda_scaling_enabled` (default `false`). |
| **10** | ArgoCD GitOps (optional) | **Scaffolded:** `bootstrap/phase-10/` (ArgoCD Helm values, `AppProject dataplatform`, example `Application` CRDs). Driver: `scripts/bootstrap-phase10.sh`. Repo URLs are placeholders — point them at your GitOps repo. |

---

## Kubernetes Namespace Strategy (spec §2.2)

| Spec namespace | Spec workloads | Repo evidence |
|----------------|----------------|---------------|
| `platform-ingestion` | NiFi, Kafka, Kafka Connect | `bootstrap/namespaces/namespaces.yaml` + `bootstrap/phase-3/manifests/{kafka,nifi}` |
| `platform-storage` | MinIO Operator, MinIO Tenant | `bootstrap/phase-2/{helm/minio-operator-values.yaml, manifests/minio/tenant.yaml}` |
| `platform-metastore` | Hive Metastore, PostgreSQL (HMS) | `bootstrap/phase-2/{helm/hive-postgresql-values.yaml, manifests/hive, manifests/postgres/cnpg-hms-cluster.yaml}` |
| `platform-compute` | Spark Operator, dbt jobs | quotas + netpol present; manifests Phase 4 (not yet) |
| `platform-orchestr` | Airflow, JupyterHub | quotas + netpol present; manifests Phase 4 (not yet) |
| `platform-serving` | Dremio, HMS Analytics | quotas + netpol present; manifests Phase 5 (not yet) |
| `platform-monitoring` | Prometheus, Grafana, OTel | quotas + netpol present; manifests Phase 6 (not yet) |
| `platform-logging` | Fluent Bit, OpenObserve | quotas + netpol present; manifests Phase 6 (not yet) |
| `platform-security` | Cloudflare Operator, **cert-manager** | namespace + quota + netpol present (PSA `privileged`); cert-manager Helm release deployed here by `scripts/bootstrap-phase2.sh` |

**All 9 spec namespaces** exist with matching `ResourceQuota` and `NetworkPolicy` (default-deny + DNS egress + same-namespace ingress). Phase 4–6 workload manifests are deferred per the phased roadmap.

## EKS cluster shape (spec §10, §12)

| Item | Spec | Repo |
|------|------|------|
| EKS managed cluster | required | `terraform/modules/eks` ✅ |
| Two managed node groups (stateful vs compute) | required for cost story §12 | `stateful-ng` (taint `workload=stateful:NoSchedule`) + `compute-ng` (untainted) ✅ |
| EBS gp3 storage class | required | `bootstrap/storage-classes/gp3-encrypted.yaml` ✅ |
| OIDC + IRSA | required | `terraform/modules/iam` (cluster-autoscaler, EBS-CSI, ESO, ALB controller) ✅ |
| KMS CMK (EBS, secrets, logs) | implied | `terraform/modules/kms` ✅ |
| VPC 3 AZ + NAT | required | `terraform/modules/vpc` ✅ |
| Terraform state on R2 | required §10.1.1 | `terraform/bootstrap` (optional bucket creation) + `scripts/tf-init-local.sh` ✅ |

---

## Non-functional requirements (traceability)

| Theme | Spec expectation | Repo evidence |
|--------|------------------|---------------|
| **IaC** | Terraform modules, remote state | `terraform/modules/*`, `terraform/environments/dev`, backend R2 config. |
| **State backend** | Cloudflare R2 | `terraform/bootstrap` **can** create bucket (`create_r2_state_bucket`, module `r2-backend-bootstrap`); R2 **S3 credentials** for Terraform remain manual (dashboard token). |
| **Security** | IRSA, KMS, private API, network policies | KMS/VPC/EKS/IAM modules; `bootstrap/network-policies/`; docs ADRs. |
| **Scalability** | Separate node groups (stateful vs compute) | `modules/eks` (per README / ADR). |
| **Ansible** | Post-bootstrap / app config per spec | **Gap:** no `ansible/` tree in repo yet — Doc (1) §13. Either add playbooks or explicitly scope Ansible “out of MVP” in mémoire with justification. |

---

## Security reminder for defense prep

- **Never** commit AWS keys, Cloudflare API tokens, or `*.tfvars` with secrets (see `.gitignore`).
- Prefer **OIDC** for GitHub → AWS (already modeled in `terraform/bootstrap`).
- Rotate any credential that was ever pasted into chat or committed by mistake.

---

## Suggested next commits (priority order)

1. **Build the Spark/dbt image** (`spark 3.5.0 + iceberg-spark-runtime + hadoop-aws + dbt-spark`) and push to ECR; replace `REPLACE_ME_REGISTRY` in `bootstrap/phase-4/manifests/spark-jobs/*.yaml`.
2. **Wire your domain in Cloudflare Tunnel** (`bootstrap/phase-6/`): create the tunnel, fill `cloudflare-tunnel-credentials.yaml` + `cloudflare-api-token.yaml`, and update FQDNs in `tunnel-bindings/`.
3. **Build the GitOps repo** (Phase 10) if you adopt ArgoCD; otherwise document why `helm` is enough for the MVP.
4. **Ansible:** minimal `ansible/` sync playbooks OR written justification if Terraform+Helm only.

---

*Generated to align repository work with PDF requirements; update this file when scope changes.*
