resource "cloudflare_r2_bucket" "terraform_state" {
  account_id = var.account_id
  name       = var.bucket_name
  # Provider expects uppercase codes: WNAM, ENAM, WEUR, EEUR, APAC, OC
  location = upper(var.location)
}
