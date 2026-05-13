output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "kubeconfig_command" {
  description = "Command to update local kubeconfig for the dev EKS cluster."
  value       = module.eks.kubeconfig_command
}

output "vpc_id" {
  description = "VPC id."
  value       = module.vpc.vpc_id
}

output "irsa_role_arns" {
  description = "Map of IRSA role ARNs created in the iam module."
  value       = module.iam.irsa_role_arns
}

output "ecr_registry_url" {
  description = "ECR registry URL (use as the Spark image prefix)."
  value       = module.ecr.registry_url
}

output "ecr_repository_urls" {
  description = "Map of ECR repo short name -> full URL."
  value       = module.ecr.repository_urls
}
