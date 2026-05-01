locals {
  github_oidc_url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 1 : 0

  url             = local.github_oidc_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  tags            = var.tags
}

locals {
  github_oidc_provider_arn = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : var.existing_github_oidc_provider_arn
}

resource "aws_iam_role" "github_actions" {
  name = var.github_actions_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.github_oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "github_actions_managed" {
  for_each = toset(var.github_actions_managed_policy_arns)

  role       = aws_iam_role.github_actions.name
  policy_arn = each.value
}

module "r2_tf_state" {
  source = "../modules/r2-backend-bootstrap"

  count = var.create_r2_state_bucket ? 1 : 0

  account_id  = var.cloudflare_account_id
  bucket_name = var.r2_state_bucket_name
  location    = var.r2_bucket_location
}

check "r2_bootstrap_inputs" {
  assert {
    condition = !var.create_r2_state_bucket || (
      var.cloudflare_account_id != null && length(var.cloudflare_account_id) > 5 &&
      var.r2_state_bucket_name != null && length(var.r2_state_bucket_name) > 2
    )
    error_message = "When create_r2_state_bucket is true, set cloudflare_account_id and r2_state_bucket_name in terraform.tfvars."
  }
}
