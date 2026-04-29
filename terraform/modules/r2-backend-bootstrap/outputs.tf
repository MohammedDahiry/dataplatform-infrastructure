output "bucket_name" {
  description = "R2 state bucket name."
  value       = var.bucket_name
}

output "r2_endpoint" {
  description = "R2 S3-compatible endpoint for this account."
  value       = "https://${var.account_id}.r2.cloudflarestorage.com"
}
