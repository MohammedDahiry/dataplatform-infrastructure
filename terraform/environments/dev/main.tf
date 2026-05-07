provider "aws" {
  region = var.aws_region
}

locals {
  common_tags = merge(var.tags, {
    environment = var.environment
    managed_by  = "terraform"
  })
}

module "kms" {
  source = "../../modules/kms"

  environment = var.environment
  name_prefix = var.name_prefix
  tags        = local.common_tags
}

module "vpc" {
  source = "../../modules/vpc"

  environment        = var.environment
  name_prefix        = var.name_prefix
  vpc_cidr           = var.vpc_cidr
  az_count           = var.az_count
  single_nat_gateway = var.single_nat_gateway
  tags               = local.common_tags
}

module "eks" {
  source = "../../modules/eks"

  environment                          = var.environment
  name_prefix                          = var.name_prefix
  cluster_name                         = var.cluster_name
  cluster_version                      = var.cluster_version
  vpc_id                               = module.vpc.vpc_id
  private_subnet_ids                   = module.vpc.private_subnet_ids
  kms_key_arn                          = module.kms.ebs_key_arn
  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_private_access      = var.cluster_endpoint_private_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  node_group_compute_desired_size      = var.node_group_compute_desired_size
  node_group_compute_min_size          = var.node_group_compute_min_size
  node_group_compute_max_size          = var.node_group_compute_max_size
  tags                                 = local.common_tags
}

module "iam" {
  source = "../../modules/iam"

  environment     = var.environment
  name_prefix     = var.name_prefix
  oidc_issuer_url = module.eks.oidc_issuer_url
  tags            = local.common_tags
}

module "lambda_scaling" {
  source = "../../modules/lambda-scaling"
  count  = var.lambda_scaling_enabled ? 1 : 0

  environment      = var.environment
  name_prefix      = var.name_prefix
  cluster_name     = module.eks.cluster_name
  node_group_name  = "compute-ng"
  schedule_enabled = var.lambda_scaling_schedule_enabled

  scale_up_cron         = var.lambda_scaling_scale_up_cron
  scale_down_cron       = var.lambda_scaling_scale_down_cron
  scale_up_min_size     = var.lambda_scaling_scale_up_min_size
  scale_up_desired_size = var.lambda_scaling_scale_up_desired_size
  scale_up_max_size     = var.lambda_scaling_scale_up_max_size

  tags = local.common_tags
}
