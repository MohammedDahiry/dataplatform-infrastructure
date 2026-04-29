output "github_actions_role_arn" {
  description = "ARN of the IAM role assumed by GitHub Actions."
  value       = aws_iam_role.github_actions.arn
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider in this AWS account."
  value       = local.github_oidc_provider_arn
}
