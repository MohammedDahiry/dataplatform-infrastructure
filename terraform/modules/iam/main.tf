locals {
  irsa_prefix = "${var.name_prefix}-${var.environment}"

  oidc_provider_url_hostpath = replace(var.oidc_issuer_url, "https://", "")

  service_accounts = {
    cluster_autoscaler = {
      namespace = "kube-system"
      name      = "cluster-autoscaler"
    }
    ebs_csi = {
      namespace = "kube-system"
      name      = "ebs-csi-controller-sa"
    }
    external_secrets = {
      namespace = "platform-security"
      name      = "external-secrets"
    }
    aws_load_balancer_controller = {
      namespace = "kube-system"
      name      = "aws-load-balancer-controller"
    }
  }
}

data "tls_certificate" "eks_oidc" {
  url = var.oidc_issuer_url
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = var.oidc_issuer_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]

  tags = var.tags
}

data "aws_iam_policy_document" "irsa_assume" {
  for_each = local.service_accounts

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url_hostpath}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url_hostpath}:sub"
      values   = ["system:serviceaccount:${each.value.namespace}:${each.value.name}"]
    }
  }
}

resource "aws_iam_role" "irsa" {
  for_each = local.service_accounts

  name               = "${local.irsa_prefix}-${replace(each.key, "_", "-")}-role"
  assume_role_policy = data.aws_iam_policy_document.irsa_assume[each.key].json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  role       = aws_iam_role.irsa["cluster_autoscaler"].name
  policy_arn = "arn:aws:iam::aws:policy/AutoScalingFullAccess"
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.irsa["ebs_csi"].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

data "aws_iam_policy_document" "external_secrets" {
  statement {
    sid    = "ReadSecrets"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecrets"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DecryptSecrets"
    effect = "Allow"
    actions = [
      "kms:Decrypt"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "external_secrets" {
  name   = "${local.irsa_prefix}-external-secrets-policy"
  policy = data.aws_iam_policy_document.external_secrets.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "external_secrets" {
  role       = aws_iam_role.irsa["external_secrets"].name
  policy_arn = aws_iam_policy.external_secrets.arn
}

data "aws_iam_policy_document" "load_balancer_controller" {
  statement {
    sid    = "ElbAndEc2"
    effect = "Allow"
    actions = [
      "ec2:Describe*",
      "ec2:CreateSecurityGroup",
      "ec2:CreateTags",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:DeleteSecurityGroup",
      "elasticloadbalancing:*",
      "acm:DescribeCertificate",
      "acm:ListCertificates",
      "iam:CreateServiceLinkedRole",
      "iam:GetServerCertificate",
      "iam:ListServerCertificates",
      "waf-regional:*",
      "wafv2:*",
      "shield:*"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "load_balancer_controller" {
  name   = "${local.irsa_prefix}-aws-load-balancer-controller-policy"
  policy = data.aws_iam_policy_document.load_balancer_controller.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "load_balancer_controller" {
  role       = aws_iam_role.irsa["aws_load_balancer_controller"].name
  policy_arn = aws_iam_policy.load_balancer_controller.arn
}
