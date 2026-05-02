variable "account_id" {
  description = "Cloudflare account ID (dashboard sidebar)."
  type        = string
}

variable "bucket_name" {
  description = "Globally unique R2 bucket name for Terraform state."
  type        = string
}

variable "location" {
  description = "R2 location hint: WNAM, ENAM, WEUR, EEUR, APAC, or OC (case-insensitive; stored uppercase)."
  type        = string
  default     = "ENAM"
}
