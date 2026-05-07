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
| **2** | MinIO Operator + Tenant, CNPG PostgreSQL, Hive Metastore, cert-manager | **Scripted path:** `scripts/bootstrap-phase2.sh` installs **cert-manager first into `platform-security`** (per spec §2.2), then MinIO → CNPG → Hive (`bootstrap/phase-2/`). **Gap:** production-grade Hive vs Bitnami Postgres-only baseline — validate against SoW; tighten TLS/Issuers for real certs. |
| **3** | Strimzi Kafka, NiFi, CDC | **Partially scaffolded:** `bootstrap/phase-3/`, `scripts/bootstrap-phase3.sh`. **Gap:** CDC flows are procedural (NiFi UI) — document / automate min pour soutenance. |
| **4** | Spark Operator, dbt, Airflow, Iceberg jobs | **Not in repo** as manifests/scripts yet (guide §5). |
| **5** | Dremio, Power BI | **Not in repo** (guide §6). |
| **6** | Cloudflare Zero Trust (Tunnel / operator) | **Not in repo** (guide §7). ADR mentions Tunnel for ingress — align implementation. |
| **7** | Prometheus, Grafana, OpenObserve, Fluent Bit | **Not in repo** (guide §8). |
| **8** | GitHub Actions CI/CD, OIDC | **Implemented** for Terraform plan/apply. **Gap:** spec also mentions Ansible + broader pipeline — optional extensions. |
| **9** | Lambda node scheduling (cost) | **Not in repo** (guide §9). |
| **10** | ArgoCD GitOps (optional) | **Not in repo** (guide §11). |

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

1. **Run Phase 2 & 3 on a live cluster** using `docs/phases/PHASE_CHECKPOINTS.md` — scripts already order cert-manager → MinIO → CNPG → Hive, then Strimzi → Kafka → NiFi.
2. **Observability slice:** kube-prometheus-stack + minimal ServiceMonitor stubs (Phase 7 subset).
3. **Cost story:** Lambda/EventBridge outline for compute node group (Phase 9) — even a documented Terraform stub strengthens the mémoire.
4. **Ansible:** minimal `ansible/` sync playbooks OR written justification if Terraform+Helm only.

---

*Generated to align repository work with PDF requirements; update this file when scope changes.*
