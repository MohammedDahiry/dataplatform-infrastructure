output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "kubeconfig_command" {
  description = "Command used to configure local kubeconfig."
  value       = module.eks.kubeconfig_command
}

output "vpc_id" {
  description = "VPC ID."
  value       = module.vpc.vpc_id
}

output "irsa_role_arns" {
  description = "IRSA role ARNs created for platform controllers."
  value       = module.iam.irsa_role_arns
}
