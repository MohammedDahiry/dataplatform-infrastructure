output "repository_urls" {
  description = "Map of short repo name -> full ECR repository URL."
  value       = { for k, r in aws_ecr_repository.this : k => r.repository_url }
}

output "registry_url" {
  description = "Account-level ECR registry URL (e.g. 123456789012.dkr.ecr.us-east-1.amazonaws.com)."
  value       = length(aws_ecr_repository.this) > 0 ? regex("^[^/]+", values(aws_ecr_repository.this)[0].repository_url) : ""
}
