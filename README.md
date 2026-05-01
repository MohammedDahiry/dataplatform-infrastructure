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

## What is delivered in Phase 1

| Component | Module / step | Purpose |
|---|---|---|
| Terraform state bucket (R2) | **Manual** in Cloudflare (dashboard) | Create the bucket, then scope an R2 API token to it; `TF_STATE_BUCKET` in GitHub. The Terraform module `modules/r2-backend-bootstrap` is reserved for a future automated bootstrap. |
| GitHub → AWS (CI) | `terraform/bootstrap` | One-time IAM OIDC provider + role for GitHub Actions (`terraform apply` with local state). |
| KMS keys | `modules/kms` | Customer-managed keys for EBS, secrets, logs |
| VPC | `modules/vpc` | 3-AZ VPC with public/private subnets, single NAT (cost-optimised) |
| IAM (IRSA) | `modules/iam` | OIDC provider + cluster-autoscaler / EBS-CSI / external-secrets / load-balancer-controller roles |
| EKS | `modules/eks` | EKS 1.30 cluster, two managed node groups (stateful + compute) |
| Bootstrap | `bootstrap/` | Namespaces, RBAC, storage class, default network policies |
| CI/CD | `.github/workflows` | OIDC-based GitHub Actions pipeline (plan on PR, apply on merge) |

## Architectural choices (and why)

- **Two node groups**, not one. `stateful-ng` (always-on, MinIO/PG/Kafka go here)
  vs. `compute-ng` (scale-to-zero outside business hours, Spark/dbt go here).
  This is what makes the Lambda scaling story in §12 of the spec actually safe —
  scaling the compute group to zero never touches data plane storage.
- **Single NAT gateway** in the MVP (one per AZ would triple egress cost). All three
  AZs route through the NAT in `us-east-1a`. Documented as a known SPOF; promotable
  to per-AZ NAT in `prod`.
- **No public endpoints** on EKS API. Private endpoint + public CIDR allow-list.
  Cloudflare Tunnel (Phase 2) is the only ingress path for users.
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

## Architecture decisions

See [`docs/02-architecture-decision-records.md`](docs/02-architecture-decision-records.md)
for the ADRs that explain why the core infrastructure choices were made.
