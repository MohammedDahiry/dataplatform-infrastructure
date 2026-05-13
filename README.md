# Cloud Data Platform — Infrastructure (PFE 2025-2026)

Author: **Mohammed Dahiry — Data Engineer**  
Scope: **Phase 1 — Landing Zone**  
Region: `us-east-1`  
State backend: Cloudflare R2 (S3-compatible)

---

## What this repo is

This repo provisions the **landing zone** for the Cloud Data Platform described in the
End-of-Studies Project Statement of Work. The landing zone is the foundation that
every later phase (MinIO, Hive Metastore, Kafka, Spark, Dremio, ...) lands on.

It contains **no application workloads**. Just the AWS + Kubernetes substrate, sized
and secured to host them.

## What is delivered

| Spec phase | Component | Module / scripts |
|---|---|---|
| **Phase 1** | Terraform state bucket (R2) | `modules/r2-backend-bootstrap` (optional) **or** manual R2 UI |
| **Phase 1** | GitHub → AWS (CI) | `terraform/bootstrap` (IAM OIDC + role) + `.github/workflows/` |
| **Phase 1** | KMS / VPC / IAM-IRSA / EKS | `modules/{kms,vpc,iam,eks}` (3-AZ, 2 node groups, gp3 default) |
| **Phase 1** | Bootstrap K8s | `bootstrap/{namespaces,storage-classes,resource-quotas,network-policies}/` (9 namespaces per spec §2.2) |
| **Phase 2** | cert-manager (in `platform-security` per spec) → MinIO Operator + Tenant → CNPG (`pg-source`, `pg-hms`) → Hive Metastore | `bootstrap/phase-2/` + `scripts/bootstrap-phase2.sh` |
| **Phase 3** | Strimzi Kafka (dev/prod variants) + topics medallion + KafkaConnect+Debezium + NiFi | `bootstrap/phase-3/` + `scripts/bootstrap-phase3.sh` |
| **Phase 4** | Spark Operator + `SparkApplication` examples + Airflow + dbt-spark skeleton | `bootstrap/phase-4/` + `scripts/bootstrap-phase4.sh` |
| **Phase 5** | Dremio Nautilus + Hive datasource | `bootstrap/phase-5/` + `scripts/bootstrap-phase5.sh` |
| **Phase 6** | Cloudflare Operator + ClusterTunnel + TunnelBindings (Airflow, Dremio, Grafana, NiFi) | `bootstrap/phase-6/` + `scripts/bootstrap-phase6.sh` |
| **Phase 7** | kube-prometheus-stack + Fluent Bit + OpenObserve + ServiceMonitors (Spark, MinIO, CNPG, Strimzi) | `bootstrap/phase-7/` + `scripts/bootstrap-phase7.sh` |
| **Phase 9** | Lambda + EventBridge scheduled scaling for `compute-ng` | `terraform/modules/lambda-scaling` (toggle `lambda_scaling_enabled`) |
| **Phase 10** | ArgoCD GitOps (optional) | `bootstrap/phase-10/` + `scripts/bootstrap-phase10.sh` |

## Architectural choices (and why)

- **Two node groups**, not one. `stateful-ng` (always-on, MinIO/PG/Kafka go here)
  vs. `compute-ng` (scale-to-zero outside business hours, Spark/dbt go here).
  This is what makes the Lambda scaling story in §12 of the spec actually safe —
  scaling the compute group to zero never touches data plane storage.
- **Single NAT gateway** in the MVP (one per AZ would triple egress cost). All three
  AZs route through the NAT in `us-east-1a`. Documented as a known SPOF; promotable
  to per-AZ NAT in `prod`.
- **No public endpoints** on EKS API. Private endpoint + public CIDR allow-list.
  Cloudflare Tunnel (Phase 6) is the intended ingress path for UIs when configured.
- **IRSA from day one.** No node-attached IAM policies. Every controller that needs
  AWS API access gets a dedicated role bound to a dedicated ServiceAccount.
- **CMKs everywhere.** EBS volumes, Secrets Manager, CloudWatch logs all use
  per-purpose customer-managed KMS keys. Aliases follow `alias/dataplatform-<purpose>-<env>`.
- **State on R2.** Per the spec, to avoid AWS dependency for state. R2 is S3-compatible,
  free up to 10 GB/mo, and lives outside the blast radius of any AWS account compromise.

## Layout

```text
.
├── terraform/
│   ├── bootstrap/                  # one-time R2 bucket + AWS OIDC for GH Actions
│   ├── modules/
│   │   ├── vpc/
│   │   ├── kms/
│   │   ├── iam/
│   │   ├── eks/
│   │   └── r2-backend-bootstrap/
│   └── environments/
│       └── dev/                    # the live environment
├── bootstrap/                      # post-terraform K8s manifests (namespaces, RBAC)
├── scripts/                        # helper shell scripts
├── docs/
└── .github/workflows/
```

## Getting started

See [`docs/01-getting-started.md`](docs/01-getting-started.md) for the bootstrap
sequence — you need to run `terraform/bootstrap/` exactly once before
`terraform/environments/dev/` will work.

**French step-by-step (what you run vs what the repo provides):** [`docs/IMPLEMENTATION_ETAPES.md`](docs/IMPLEMENTATION_ETAPES.md).

**Tight deadline / defense prep:** [`docs/SOUTENANCE_EXPRESS.md`](docs/SOUTENANCE_EXPRESS.md) — minimum demo scope, report outline, `fasttrack` ordering.

### Complete startup walkthrough

See **[`docs/STARTUP_GUIDE.md`](docs/STARTUP_GUIDE.md)** — single document that
covers every step from a fresh clone to a running medallion pipeline (Phases 1
through 10), Cloudflare tunnel publishing, and the destroy / re-apply cycle.

## Stop / start cycle (avoid AWS charges)

```bash
# Stop billing at end of day
./scripts/teardown-infra.sh --auto-approve

# Bring everything back next morning (Phase 1 + 2)
./scripts/fasttrack-infra.sh --auto-approve --with-phase2

# Or everything (2..7) in one shot
./scripts/fasttrack-infra.sh --auto-approve --with-all
```

`teardown-infra.sh` uninstalls Helm releases, deletes PVCs (releases EBS) and `LoadBalancer` services (releases ELB), then runs `terraform destroy` on `terraform/environments/dev`. It does **not** touch `terraform/bootstrap` nor the R2 state bucket, so the next `terraform apply` reuses the same remote state.

## Specification traceability (PFE)

The official PDFs under [`docs/specs/`](docs/specs/) are mapped to this repo in [`docs/specs/SPEC_ALIGNMENT.md`](docs/specs/SPEC_ALIGNMENT.md) (phases, gaps, next steps).

**Operational checkpoints (when to run Phase 2 vs 3):** [`docs/phases/PHASE_CHECKPOINTS.md`](docs/phases/PHASE_CHECKPOINTS.md).

## Architecture decisions

See [`docs/02-architecture-decision-records.md`](docs/02-architecture-decision-records.md)
for the ADRs that explain why the core infrastructure choices were made.
