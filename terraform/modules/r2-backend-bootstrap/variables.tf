variable "account_id" {
  description = "Cloudflare account ID (dashboard sidebar)."
  type        = string
}

variable "bucket_name" {
  description = "Globally unique R2 bucket name for Terraform state."
  type        = string
}

variable "location" {
  description = "R2 location hint (e.g. enam, weur). See Cloudflare R2 docs."
  type        = string
  default     = "enam"
}
