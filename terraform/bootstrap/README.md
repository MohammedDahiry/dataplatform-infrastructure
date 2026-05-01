# Terraform Bootstrap

One-time stack run from your laptop (local state — **do not commit** `terraform.tfstate` once it is real).

It provisions:

1. **AWS:** GitHub OIDC provider (optional) + IAM role for GitHub Actions.
2. **Cloudflare R2 (optional):** Terraform state bucket via module `modules/r2-backend-bootstrap` when `create_r2_state_bucket = true`.

## Prerequisites

- AWS credentials (named profile recommended).
- For R2 bucket creation: `export CLOUDFLARE_API_TOKEN=...` with a token allowed to manage R2 buckets on the account.

## Apply

```bash
cd terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars
# Edit: github_org, github_repo; optionally enable create_r2_state_bucket + Cloudflare IDs

export CLOUDFLARE_API_TOKEN=...   # only if creating R2 bucket via Terraform

terraform init
terraform apply
terraform output
```

Outputs include `github_actions_role_arn` and, when enabled, `r2_state_bucket_name` for the GitHub variable `TF_STATE_BUCKET`.

You still create **R2 S3-compatible access keys** for Terraform backend auth in the Cloudflare dashboard (object read/write on that bucket) — Terraform cannot mint those keys via API today.

## If OIDC provider already exists

Set:

```hcl
create_github_oidc_provider     = false
existing_github_oidc_provider_arn = "arn:aws:iam::<account-id>:oidc-provider/token.actions.githubusercontent.com"
```
