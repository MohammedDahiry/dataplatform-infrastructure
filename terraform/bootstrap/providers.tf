provider "aws" {
  region = var.aws_region

  profile = var.aws_profile
}

provider "cloudflare" {
  # api_token: use env CLOUDFLARE_API_TOKEN (recommended). Never commit secrets.
}
