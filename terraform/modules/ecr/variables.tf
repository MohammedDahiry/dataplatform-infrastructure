variable "environment" {
  description = "Environment name."
  type        = string
}

variable "name_prefix" {
  description = "Resource name prefix."
  type        = string
}

variable "repositories" {
  description = "List of ECR repositories to create. Names are prefixed with '<name_prefix>/' (multi-level path style)."
  type        = list(string)
  default     = ["spark-iceberg"]
}

variable "image_tag_mutability" {
  description = "Whether tags can be overwritten."
  type        = string
  default     = "MUTABLE"
  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be MUTABLE or IMMUTABLE."
  }
}

variable "scan_on_push" {
  description = "Run AWS-managed image scan on push."
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "KMS CMK ARN used to encrypt ECR images. If null, AES256 is used."
  type        = string
  default     = null
}

variable "tags" {
  description = "Common resource tags."
  type        = map(string)
  default     = {}
}

variable "lifecycle_keep_last_n" {
  description = "Keep only the last N tagged images per repo. Untagged images are removed after 7 days."
  type        = number
  default     = 10
}
