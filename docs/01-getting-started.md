# Getting Started — Phase 1 Landing Zone

End-to-end walkthrough from a fresh clone to a working EKS cluster ready for
Phase 2 workloads. Budget about 30-45 minutes of wall-clock time, most of which
is waiting for `terraform apply` to finish.

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

## Step 0 — Configure AWS profile

```bash
aws configure --profile dataplatform-admin
# Enter access key, secret, region us-east-1, output json
export AWS_PROFILE=dataplatform-admin
aws sts get-caller-identity   # sanity check
```

## Step 1 — Run the bootstrap stack (once)

The bootstrap stack creates:

1. The Cloudflare R2 bucket that holds Terraform state for everything else.
2. The IAM OIDC role that GitHub Actions assumes.

It uses **local state**, committed once and then frozen.

```bash
cd terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars:
#   - cloudflare_account_id: get from CF dashboard right sidebar
#   - github_org / github_repo: where this code lives

export CLOUDFLARE_API_TOKEN=...    # Cloudflare > My Profile > API Tokens

terraform init
terraform apply
```

Capture the outputs:

```bash
terraform output
# r2_bucket_name             -> dataplatform-tfstate-pfe
# r2_endpoint                -> https://abc123.r2.cloudflarestorage.com
# github_actions_role_arn    -> arn:aws:iam::123456789012:role/dataplatform-github-actions
```

### Step 1.5 — Create the R2 API token (manual, one-time)

The Cloudflare provider can't yet create R2 access keys declaratively, so:

1. CF Dashboard → R2 → "Manage R2 API tokens" → "Create API token".
2. Name it `terraform-state-rw`.
3. Permissions: **Object Read & Write**, scoped to the bucket created above.
4. Copy the **Access Key ID** and **Secret Access Key**.

### Step 1.6 — Seed GitHub Secrets

In your repo → Settings → Secrets and variables → Actions, add:

| Secret | Value |
|---|---|
| `AWS_GH_ACTIONS_ROLE_ARN` | `github_actions_role_arn` from Step 1 |
| `CF_R2_ACCESS_KEY_ID` | Access key from Step 1.5 |
| `CF_R2_SECRET_ACCESS_KEY` | Secret key from Step 1.5 |
| `CF_ACCOUNT_ID` | Your Cloudflare account ID |

Also create a GitHub Environment named `dev` (Settings → Environments) and
add yourself as a required reviewer. This gates `terraform apply` on a manual
approval click.

Add a repository variable as well (Settings → Secrets and variables → Actions → Variables):

| Variable | Value |
|---|---|
| `TF_STATE_BUCKET` | `r2_bucket_name` from Step 1 |

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
- Auth failures → re-check the GitHub Secrets you set in Step 1.6.
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
# 9 platform-* namespaces

kubectl get storageclass
# gp3 (default), gp2

kubectl get resourcequota -A
# One per platform namespace

kubectl get networkpolicy -A
# Default-deny + DNS-allow + same-NS in every namespace
```

If all four show the expected output, the landing zone is live.

## Where to go from here

Phase 2 is the storage layer (MinIO Operator → Tenant), the catalog
(CloudNativePG → Hive Metastore), and the security layer (cert-manager,
Cloudflare Tunnel, External Secrets Operator). All three install via Helm into
the namespaces the bootstrap created.

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
