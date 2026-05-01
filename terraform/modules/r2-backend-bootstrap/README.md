# Terraform Module: R2 Backend Bootstrap

Creates a **Cloudflare R2 bucket** used as the **S3-compatible remote backend** for Terraform (see `terraform/environments/dev/backend.tf`).

## Requirements

- API token with permission to manage R2 (e.g. **Account → Workers R2 Storage → Edit** scope for the account).
- Set `CLOUDFLARE_API_TOKEN` in the environment before `terraform apply` (never commit tokens).

## Usage

Called from `terraform/bootstrap/` when `create_r2_state_bucket = true`.

R2 **S3 API credentials** for Terraform backend access are still created **manually** in the Cloudflare dashboard (object read/write scoped to this bucket), as in `docs/01-getting-started.md`.
