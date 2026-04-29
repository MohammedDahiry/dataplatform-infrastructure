output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "kubeconfig_command" {
  description = "Command to update kubeconfig for this cluster."
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.this.name} --region us-east-1"
}

output "cluster_arn" {
  description = "EKS cluster ARN."
  value       = aws_eks_cluster.this.arn
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL of the EKS cluster."
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}
