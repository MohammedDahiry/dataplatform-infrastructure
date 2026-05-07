variable "environment" {
  description = "Environment name."
  type        = string
}

variable "name_prefix" {
  description = "Resource name prefix."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "tags" {
  description = "Common resource tags."
  type        = map(string)
  default     = {}
}

variable "cluster_version" {
  description = "EKS Kubernetes version."
  type        = string
  default     = "1.30"
}

variable "vpc_id" {
  description = "VPC ID where EKS is deployed."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for control plane and node groups."
  type        = list(string)
}

variable "kms_key_arn" {
  description = "KMS key ARN used by EKS secrets encryption."
  type        = string
  default     = null
}

variable "cluster_endpoint_public_access" {
  description = "Enable public API endpoint."
  type        = bool
  default     = false
}

variable "cluster_endpoint_private_access" {
  description = "Enable private API endpoint."
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "Allowed CIDRs for public endpoint access."
  type        = list(string)
  default     = []
}

variable "node_group_stateful_desired_size" {
  description = "Stateful node group desired count."
  type        = number
  default     = 1
}

variable "node_group_stateful_min_size" {
  description = "Stateful node group minimum."
  type        = number
  default     = 1
}

variable "node_group_stateful_max_size" {
  description = "Stateful node group maximum."
  type        = number
  default     = 3
}

variable "node_group_compute_desired_size" {
  description = "Compute node group desired count (untainted). Use >=1 in dev if operators must schedule while compute pool is the non-stateful option."
  type        = number
  default     = 0
}

variable "node_group_compute_min_size" {
  description = "Compute node group minimum."
  type        = number
  default     = 0
}

variable "node_group_compute_max_size" {
  description = "Compute node group maximum."
  type        = number
  default     = 10
}
