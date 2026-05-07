# Getting Started — Phase 1 Landing Zone

End-to-end walkthrough from a fresh clone to a working EKS cluster ready for
Phase 2 workloads. Budget about 30-45 minutes of wall-clock time, most of which
is waiting for `terraform apply` to finish.

**Guide d’implémentation étape par étape (FR, vous vs dépôt) :** [`IMPLEMENTATION_ETAPES.md`](IMPLEMENTATION_ETAPES.md).

## Prerequisites

| Tool | Version | Why |
|---|---|---|
| `terraform` | 1.9.x or 1.10.x | IaC engine |
| `aws` CLI | v2 | Manages AWS credentials and EKS kubeconfig |
| `kubectl` | matches cluster minor | Talks to the cluster |
| `helm` | 3.14+ | Phase 2 (operators); not strictly needed in Phase 1 |
| `git` | any | Cloning the repo |

You will also need:

- **An AWS account** with admin rights, accessed via a named profile in `~/.aws/credentials` (e.g. `dataplatform-admin`).
- **A Cloudflare account** with an API token that can create R2 buckets.
- **A GitHub repository** that holds this code — needs admin rights to add Secrets and Environments.

### Using WSL (Ubuntu on Windows)

All commands in this guide assume a normal Linux shell — **WSL2 is supported and recommended** for `kubectl`, `helm`, `terraform`, and `aws` (install them *inside* WSL, not only on Windows).

- Prefer cloning the repo under your Linux home, e.g. `~/projects/...`, not only under `/mnt/c/...`, so file permissions and line endings stay predictable.
- If a script fails with `bash\r: No such file or directory`, the file has Windows CRLF endings — open it in your editor and set **LF**, or run `sed -i 's/\r$//' scripts/<name>.sh`.
- `kubectl` uses `~/.kube/config`; run `aws eks update-kubeconfig` **in the same WSL** where you run `./scripts/bootstrap-cluster.sh`.

The assistant cannot reach your WSL or your AWS account; you still run the commands locally even when the repo lives on Windows disks mounted into WSL.

## Step 0 — Configure AWS profile

```bash
aws configure --profile dataplatform-admin
# Enter access key, secret, region us-east-1, output json
export AWS_PROFILE=dataplatform-admin
aws sts get-caller-identity   # sanity check
```

## Step 1 — Bootstrap: GitHub Actions (AWS) + optional R2 bucket (once)

The stack in `terraform/bootstrap/` creates:

1. **AWS:** (Optional) GitHub OIDC provider in IAM + IAM role for GitHub Actions + policy attachments.
2. **Cloudflare R2 (optional):** If you set `create_r2_state_bucket = true` in `terraform.tfvars`, Terraform creates the state bucket via `modules/r2-backend-bootstrap`. Otherwise create the bucket manually in the R2 UI (same end state).

It uses **local state** — do not commit `terraform.tfstate` after it contains real ARNs.

```bash
cd terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: github_org, github_repo, aws_profile.
# Optional: create_r2_state_bucket = true, cloudflare_account_id, r2_state_bucket_name

export CLOUDFLARE_API_TOKEN=...   # required only if create_r2_state_bucket = true

terraform init
terraform apply
```

Capture the outputs:

```bash
terraform output
# github_actions_role_arn    -> arn:aws:iam::123456789012:role/dataplatform-github-actions
# github_oidc_provider_arn   -> ...
# r2_state_bucket_name       -> (if R2 bucket created here) dataplatform-tfstate-pfe
```

### Step 1.5 — Create the R2 bucket for Terraform state (manual path only)

Skip this if Step 1 already created the bucket (`r2_state_bucket_name` output).

1. Cloudflare Dashboard → **R2** → **Create bucket** (e.g. `dataplatform-tfstate-pfe`).
2. Note the **bucket name** — you will set `TF_STATE_BUCKET` to this value.

### Step 1.6 — Create the R2 API token (manual, one-time)

1. CF Dashboard → R2 → **Manage R2 API tokens** → **Create API token**.
2. Name it e.g. `terraform-state-rw`.
3. Permissions: **Object Read & Write**, scoped to the bucket from Step 1.5.
4. Copy the **Access Key ID** and **Secret Access Key**.

### Step 1.7 — Seed GitHub Secrets

In your repo → Settings → Secrets and variables → Actions, add:

| Secret | Value |
|---|---|
| `AWS_GH_ACTIONS_ROLE_ARN` | `github_actions_role_arn` from Step 1 |
| `CF_R2_ACCESS_KEY_ID` | Access key from Step 1.6 |
| `CF_R2_SECRET_ACCESS_KEY` | Secret key from Step 1.6 |
| `CF_ACCOUNT_ID` | Your Cloudflare account ID |

Also create a GitHub Environment named `dev` (Settings → Environments) and
add yourself as a required reviewer. This gates `terraform apply` on a manual
approval click.

Add a repository variable as well (Settings → Secrets and variables → Actions → Variables):

| Variable | Value |
|---|---|
| `TF_STATE_BUCKET` | Bucket name from Step 1.5 |

## Step 2 — Wire up the dev environment backend

The CI workflow injects backend settings dynamically from GitHub Secrets/Variables.
For local initialization, use:

```bash
export TF_STATE_BUCKET=dataplatform-tfstate-pfe
export CF_ACCOUNT_ID=YOUR_CF_ACCOUNT_ID
export CF_R2_ACCESS_KEY_ID=...
export CF_R2_SECRET_ACCESS_KEY=...

./scripts/tf-init-local.sh terraform/environments/dev
```

Commit and push your branch. Open a PR to `main`.

## Step 3 — First plan (via PR)

The CI pipeline kicks in automatically. The `Terraform Plan` job runs
`terraform plan` against the dev environment and posts the output as a PR
comment.

**Expected:** the plan shows ~80-100 resources to create.

If something fails:

- `lint` failures → run `terraform fmt -recursive` locally.
- Auth failures → re-check the GitHub Secrets you set in Step 1.7.
- "bucket does not exist" → re-check `backend.tf` matches Step 1 outputs.

## Step 4 — First apply

Merge the PR. The `Terraform Apply` job:

1. Re-plans against current state (because plans drift between PR open and merge).
2. Pauses awaiting your approval in the `dev` Environment.
3. Applies on approval. Takes 12-18 minutes (mostly EKS control-plane creation).

Watch the Action logs in the GitHub UI. On success, the final step prints all
outputs including the cluster name and kubeconfig command.

## Step 5 — Bootstrap the cluster

Now from your laptop:

```bash
# Get kubectl access via aws-eks-cluster role.
# Note: by default the API endpoint is PRIVATE. For initial bring-up, you
# have two options:
#
#   A. Temporarily flip cluster_endpoint_public_access = true in your
#      tfvars, scoped to your laptop's IP. PR + apply.
#   B. Use SSM Session Manager via a bastion in the VPC.
#
# Option A is fine for an MVP — you can flip it back once Cloudflare Tunnel
# is up.

cd terraform/environments/dev
terraform output kubeconfig_command
# Copy and run the printed command, e.g.:
aws eks update-kubeconfig --name dataplatform-dev --region us-east-1

# Then run the post-terraform bootstrap script:
cd ../../..
./scripts/bootstrap-cluster.sh
```

This applies namespaces, the encrypted gp3 storage class, resource quotas, and
network policies. Idempotent — re-run safely.

## Step 6 — Verify

```bash
kubectl get nodes
# 5 nodes Ready (3 stateful + 2 compute)

kubectl get ns -l app.kubernetes.io/part-of=dataplatform
# 9 platform-* namespaces (cert-manager lives inside platform-security per spec §2.2)

kubectl get storageclass
# gp3 (default), gp2

kubectl get resourcequota -A
# One per platform namespace

kubectl get networkpolicy -A
# Default-deny + DNS-allow + same-NS in every namespace
```

If all four show the expected output, the landing zone is live.

## Where to go from here

Use **[`docs/phases/PHASE_CHECKPOINTS.md`](phases/PHASE_CHECKPOINTS.md)** before installing workloads: it defines when to run Phase 2 vs Phase 3.

To generate Phase 2 secrets locally (random values, not committed): **`./scripts/prepare-phase2-secrets.sh`**.

Phase 2 is cert-manager (in `platform-security` per spec §2.2), the storage layer
(MinIO Operator → Tenant), the catalog (CloudNativePG → Hive Metastore), and later
additional security workloads (Cloudflare Tunnel, External Secrets Operator, etc.).
Helm installs are scripted in `scripts/bootstrap-phase2.sh` into the namespaces
Phase 1 created.

## Cost expectations

At rest with `compute-ng` scaled to zero (out of business hours):

- EKS control plane: $0.10/hr × 24 × 30 = **~$72/mo**
- 3× m6i.large stateful nodes: ~$0.096/hr × 3 × 24 × 30 = **~$207/mo**
- 1× NAT gateway: ~$32/mo + egress
- 3× EBS volumes (100 GiB gp3): ~$24/mo
- KMS keys: $1/mo each × 3 = $3/mo
- R2 bucket: free (under 10 GB)

Baseline: **~$340/mo**. With compute-ng running business hours only (10/24),
add ~$60/mo. With both NGs running 24/7, add ~$200/mo on top.

## Troubleshooting

**`terraform init` fails with "Failed to retrieve credentials"**: you exported
`AWS_PROFILE` but not `AWS_ACCESS_KEY_ID` for the R2 backend. Use
`scripts/tf-init-local.sh` instead.

**`kubectl` hangs on cluster commands**: the API endpoint is private. Either
flip the public-access variables temporarily (Step 5 option A), or set up
Session Manager.

**Apply fails on `aws_eks_addon.ebs_csi`**: usually a chicken-and-egg with
IRSA. Re-run `terraform apply`; the second pass succeeds.

**`tfsec` flags a finding on PR**: the CI is set to `soft_fail` for now —
review findings, suppress with code comments, but don't block merges on them
during MVP.
