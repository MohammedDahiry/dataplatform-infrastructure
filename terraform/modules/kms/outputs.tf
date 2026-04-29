output "key_alias_prefix" {
  description = "Prefix to use for KMS key aliases."
  value       = local.key_alias_prefix
}

output "ebs_key_arn" {
  description = "ARN of EBS KMS key."
  value       = aws_kms_key.ebs.arn
}

output "secrets_key_arn" {
  description = "ARN of Secrets KMS key."
  value       = aws_kms_key.secrets.arn
}

output "logs_key_arn" {
  description = "ARN of Logs KMS key."
  value       = aws_kms_key.logs.arn
}
