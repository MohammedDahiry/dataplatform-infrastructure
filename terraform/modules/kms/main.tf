locals {
  key_alias_prefix = "alias/${var.name_prefix}"
}

resource "aws_kms_key" "ebs" {
  description             = "CMK for EBS encryption (${var.environment})"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ebs-${var.environment}"
  })
}

resource "aws_kms_alias" "ebs" {
  name          = "${local.key_alias_prefix}-ebs-${var.environment}"
  target_key_id = aws_kms_key.ebs.key_id
}

resource "aws_kms_key" "secrets" {
  description             = "CMK for Secrets Manager encryption (${var.environment})"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-secrets-${var.environment}"
  })
}

resource "aws_kms_alias" "secrets" {
  name          = "${local.key_alias_prefix}-secrets-${var.environment}"
  target_key_id = aws_kms_key.secrets.key_id
}

resource "aws_kms_key" "logs" {
  description             = "CMK for CloudWatch Logs encryption (${var.environment})"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-logs-${var.environment}"
  })
}

resource "aws_kms_alias" "logs" {
  name          = "${local.key_alias_prefix}-logs-${var.environment}"
  target_key_id = aws_kms_key.logs.key_id
}
