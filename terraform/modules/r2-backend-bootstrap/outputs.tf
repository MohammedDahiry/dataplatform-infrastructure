output "bucket_name" {
  description = "R2 bucket name (use as TF_STATE_BUCKET / S3 backend bucket)."
  value       = cloudflare_r2_bucket.terraform_state.name
}

output "bucket_id" {
  description = "Cloudflare provider-assigned bucket id."
  value       = cloudflare_r2_bucket.terraform_state.id
}
