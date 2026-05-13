variable "aws_region" {
  description = "AWS region for the landing zone."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "dev"
}

variable "name_prefix" {
  description = "Prefix used for naming resources."
  type        = string
  default     = "dataplatform"
}

variable "tags" {
  description = "Common tags applied to resources."
  type        = map(string)
  default = {
    project = "cloud-data-platform"
    phase   = "landing-zone"
  }
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
  default     = "dataplatform-dev"
}

variable "cluster_version" {
  description = "EKS Kubernetes version."
  type        = string
  default     = "1.30"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC."
  type        = string
  default     = "10.10.0.0/16"
}

variable "az_count" {
  description = "Number of AZs to use."
  type        = number
  default     = 3
}

variable "single_nat_gateway" {
  description = "If true, use one NAT gateway for all private subnets."
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Enable public endpoint for EKS API."
  type        = bool
  default     = false
}

variable "cluster_endpoint_private_access" {
  description = "Enable private endpoint for EKS API."
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to access public endpoint."
  type        = list(string)
  default     = []
}

variable "node_group_stateful_desired_size" {
  description = "Stateful node group (tainted workload=stateful) desired count."
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
  description = "Compute (untainted) node group desired count. Use >=1 so cert-manager and other operators schedule when only stateful nodes carry workload=stateful taint."
  type        = number
  default     = 1
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

variable "lambda_scaling_enabled" {
  description = "Whether to deploy the Lambda+EventBridge schedule that scales compute-ng (spec §12)."
  type        = bool
  default     = false
}

variable "lambda_scaling_schedule_enabled" {
  description = "Whether the EventBridge cron rules created by the lambda_scaling module are ENABLED."
  type        = bool
  default     = true
}

variable "lambda_scaling_scale_up_cron" {
  description = "EventBridge cron expression (UTC) for scale-up."
  type        = string
  default     = "cron(0 7 ? * MON-FRI *)"
}

variable "lambda_scaling_scale_down_cron" {
  description = "EventBridge cron expression (UTC) for scale-down."
  type        = string
  default     = "cron(0 17 ? * MON-FRI *)"
}

variable "lambda_scaling_scale_up_min_size" {
  description = "compute-ng min size when scaled up."
  type        = number
  default     = 1
}

variable "lambda_scaling_scale_up_desired_size" {
  description = "compute-ng desired size when scaled up."
  type        = number
  default     = 1
}

variable "lambda_scaling_scale_up_max_size" {
  description = "compute-ng max size when scaled up."
  type        = number
  default     = 10
}

variable "ecr_repositories" {
  description = "ECR repos to create for platform images (under the name_prefix/* path)."
  type        = list(string)
  default     = ["spark-iceberg"]
}
