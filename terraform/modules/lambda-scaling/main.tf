data "aws_iam_policy_document" "assume_lambda" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.name_prefix}-${var.environment}-eks-scaler-role"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda_inline" {
  statement {
    effect = "Allow"
    actions = [
      "eks:DescribeNodegroup",
      "eks:UpdateNodegroupConfig",
      "eks:ListNodegroups"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "lambda_inline" {
  name   = "${var.name_prefix}-${var.environment}-eks-scaler-inline"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.lambda_inline.json
}

data "archive_file" "scaler_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/scaler.py"
  output_path = "${path.module}/build/scaler.zip"
}

resource "aws_lambda_function" "scaler" {
  function_name    = "${var.name_prefix}-${var.environment}-eks-scaler"
  role             = aws_iam_role.this.arn
  filename         = data.archive_file.scaler_zip.output_path
  source_code_hash = data.archive_file.scaler_zip.output_base64sha256
  handler          = "scaler.handler"
  runtime          = "python3.12"
  timeout          = 60

  environment {
    variables = {
      CLUSTER_NAME    = var.cluster_name
      NODE_GROUP_NAME = var.node_group_name
      MIN_SIZE        = tostring(var.scale_up_min_size)
      DESIRED_SIZE    = tostring(var.scale_up_desired_size)
      MAX_SIZE        = tostring(var.scale_up_max_size)
    }
  }

  tags = var.tags
}

resource "aws_cloudwatch_event_rule" "scale_up" {
  name                = "${var.name_prefix}-${var.environment}-eks-scale-up"
  description         = "Scale up ${var.node_group_name} on weekday mornings."
  schedule_expression = var.scale_up_cron
  state               = var.schedule_enabled ? "ENABLED" : "DISABLED"
  tags                = var.tags
}

resource "aws_cloudwatch_event_rule" "scale_down" {
  name                = "${var.name_prefix}-${var.environment}-eks-scale-down"
  description         = "Scale down ${var.node_group_name} on weekday evenings."
  schedule_expression = var.scale_down_cron
  state               = var.schedule_enabled ? "ENABLED" : "DISABLED"
  tags                = var.tags
}

resource "aws_cloudwatch_event_target" "scale_up" {
  rule      = aws_cloudwatch_event_rule.scale_up.name
  target_id = "scale-up"
  arn       = aws_lambda_function.scaler.arn
  input = jsonencode({
    action = "scale_up"
  })
}

resource "aws_cloudwatch_event_target" "scale_down" {
  rule      = aws_cloudwatch_event_rule.scale_down.name
  target_id = "scale-down"
  arn       = aws_lambda_function.scaler.arn
  input = jsonencode({
    action = "scale_down"
  })
}

resource "aws_lambda_permission" "allow_eb_up" {
  statement_id  = "AllowExecutionFromEventBridgeUp"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scaler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scale_up.arn
}

resource "aws_lambda_permission" "allow_eb_down" {
  statement_id  = "AllowExecutionFromEventBridgeDown"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scaler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scale_down.arn
}
