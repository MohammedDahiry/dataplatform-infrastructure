output "github_actions_role_arn" {
  description = "ARN of the IAM role assumed by GitHub Actions."
  value       = aws_iam_role.github_actions.arn
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider in this AWS account."
  value       = local.github_oidc_provider_arn
}

output "r2_state_bucket_name" {
  description = "R2 bucket name for Terraform remote state (null if create_r2_state_bucket is false)."
  value       = try(module.r2_tf_state[0].bucket_name, null)
}
