output "irsa_prefix" {
  description = "Name prefix for IRSA roles."
  value       = local.irsa_prefix
}

output "oidc_provider_arn" {
  description = "ARN of IAM OIDC provider for EKS."
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "irsa_role_arns" {
  description = "Map of IRSA role ARNs by logical name."
  value       = { for k, v in aws_iam_role.irsa : k => v.arn }
}
