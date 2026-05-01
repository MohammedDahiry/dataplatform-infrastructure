# Terraform Bootstrap

One-time bootstrap stack for:

- GitHub Actions OIDC role creation in **AWS**

**Not included:** Cloudflare R2 bucket creation — create the state bucket in the R2 UI (see `docs/01-getting-started.md`), then store credentials in GitHub Secrets for CI.

This stack is intentionally separate from environment stacks.

## What it creates

- GitHub OIDC provider in IAM (`token.actions.githubusercontent.com`) when enabled
- IAM role for GitHub Actions (`dataplatform-github-actions` by default)
- Managed policy attachments to that role

## Apply

```bash
cd terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars
# Edit github_org / github_repo and optional aws_profile

terraform init
terraform apply
terraform output
```

## If OIDC provider already exists

Set:

```hcl
create_github_oidc_provider     = false
existing_github_oidc_provider_arn = "arn:aws:iam::<account-id>:oidc-provider/token.actions.githubusercontent.com"
```
