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
| **2** | MinIO Operator + Tenant, CNPG PostgreSQL, Hive Metastore, cert-manager | **Partially scaffolded:** `bootstrap/phase-2/`, `scripts/bootstrap-phase2.sh`. **Gap:** cert-manager, production-grade Hive chart choice vs Bitnami Postgres-only baseline — validate against SoW. |
| **3** | Strimzi Kafka, NiFi, CDC | **Partially scaffolded:** `bootstrap/phase-3/`, `scripts/bootstrap-phase3.sh`. **Gap:** CDC flows are procedural (NiFi UI) — document / automate min pour soutenance. |
| **4** | Spark Operator, dbt, Airflow, Iceberg jobs | **Not in repo** as manifests/scripts yet (guide §5). |
| **5** | Dremio, Power BI | **Not in repo** (guide §6). |
| **6** | Cloudflare Zero Trust (Tunnel / operator) | **Not in repo** (guide §7). ADR mentions Tunnel for ingress — align implementation. |
| **7** | Prometheus, Grafana, OpenObserve, Fluent Bit | **Not in repo** (guide §8). |
| **8** | GitHub Actions CI/CD, OIDC | **Implemented** for Terraform plan/apply. **Gap:** spec also mentions Ansible + broader pipeline — optional extensions. |
| **9** | Lambda node scheduling (cost) | **Not in repo** (guide §9). |
| **10** | ArgoCD GitOps (optional) | **Not in repo** (guide §11). |

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

1. **Phase 2 end-to-end:** cert-manager → MinIO operator → tenant → CNPG → Hive (single documented path matching `Doc (1).pdf`).
2. **Observability slice:** kube-prometheus-stack + minimal ServiceMonitor stubs (Phase 7 subset).
3. **Cost story:** Lambda/EventBridge outline for compute node group (Phase 9) — even a documented Terraform stub strengthens the mémoire.
4. **Ansible:** minimal `ansible/` sync playbooks OR written justification if Terraform+Helm only.

---

*Generated to align repository work with PDF requirements; update this file when scope changes.*
