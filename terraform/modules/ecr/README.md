# `ecr` — container registry for platform images

Creates one ECR repository per name in `var.repositories`. Used for the
`spark-iceberg` image consumed by Phase 4 `SparkApplication` CRDs.

## Defaults

- Tag mutability: `MUTABLE` (toggle to `IMMUTABLE` for production).
- Scan on push: enabled.
- Encryption: KMS if `kms_key_arn` is provided, else AES256.
- Lifecycle: keep last 10 tagged images, expire untagged after 7 days.

## Outputs

- `repository_urls`: map `name -> repo URL`.
- `registry_url`: account-level registry URL (suitable for `docker login` / image refs).

## Example wiring (already in `terraform/environments/dev`)

```hcl
module "ecr" {
  source = "../../modules/ecr"

  environment   = var.environment
  name_prefix   = var.name_prefix
  repositories  = ["spark-iceberg"]
  kms_key_arn   = module.kms.ebs_key_arn
  tags          = local.common_tags
}
```