resource "cloudflare_r2_bucket" "terraform_state" {
  account_id = var.account_id
  name       = var.bucket_name
  location   = var.location
}
