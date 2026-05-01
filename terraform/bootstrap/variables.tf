variable "aws_region" {
  description = "AWS region used for bootstrap resources."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Optional AWS CLI profile used by the AWS provider."
  type        = string
  default     = null
}

variable "github_org" {
  description = "GitHub organization or user that owns the repository."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name."
  type        = string
}

variable "create_github_oidc_provider" {
  description = "Create GitHub OIDC provider if it does not already exist."
  type        = bool
  default     = true
}

variable "existing_github_oidc_provider_arn" {
  description = "Existing GitHub OIDC provider ARN to use when create_github_oidc_provider is false."
  type        = string
  default     = null
}

variable "github_actions_role_name" {
  description = "IAM role name assumed by GitHub Actions."
  type        = string
  default     = "dataplatform-github-actions"
}

variable "github_actions_managed_policy_arns" {
  description = "Managed policies attached to the GitHub Actions role."
  type        = list(string)
  default     = ["arn:aws:iam::aws:policy/AdministratorAccess"]
}

variable "tags" {
  description = "Common tags for bootstrap resources."
  type        = map(string)
  default = {
    project = "cloud-data-platform"
    phase   = "landing-zone"
  }
}

variable "create_r2_state_bucket" {
  description = "If true, create the Cloudflare R2 bucket via Terraform (requires CLOUDFLARE_API_TOKEN in env)."
  type        = bool
  default     = false
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID (required when create_r2_state_bucket is true)."
  type        = string
  default     = null
  nullable    = true
}

variable "r2_state_bucket_name" {
  description = "Unique name for the Terraform state bucket on R2 (required when create_r2_state_bucket is true)."
  type        = string
  default     = null
  nullable    = true
}

variable "r2_bucket_location" {
  description = "R2 location hint (enam, weur, wnam, etc.). See Cloudflare docs."
  type        = string
  default     = "enam"
}
