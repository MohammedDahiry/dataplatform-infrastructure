# `lambda-scaling` — Phase 9

Implements `Specifications_Doc_for_PFE.pdf` §12: schedule-driven scaling of the
EKS **compute** managed node group via Lambda + EventBridge. Stateful node groups
are never touched.

## Resources

- IAM role for Lambda with `eks:Update/Describe/ListNodegroup` only.
- Lambda (`python3.12`, `lambda/scaler.py`) packaged via `archive_file`.
- Two EventBridge cron rules (default: `08:00`/`18:00` Europe/Paris weekdays).
- Two `aws_lambda_permission` to allow EventBridge to invoke the function.

## Usage from `terraform/environments/dev`

```hcl
module "lambda_scaling" {
  source = "../../modules/lambda-scaling"

  environment      = var.environment
  name_prefix      = var.name_prefix
  cluster_name     = module.eks.cluster_name
  node_group_name  = "compute-ng"
  schedule_enabled = var.lambda_scaling_enabled
  tags             = local.common_tags
}
```

Disable temporarily without removing the module: `lambda_scaling_enabled = false`.

## Manual test

```bash
aws lambda invoke \
  --function-name dataplatform-dev-eks-scaler \
  --payload '{"action":"scale_up"}' \
  --cli-binary-format raw-in-base64-out \
  /tmp/out.json && cat /tmp/out.json
```