output "lambda_function_arn" {
  description = "ARN of the EKS scaler Lambda."
  value       = aws_lambda_function.scaler.arn
}

output "scale_up_rule_arn" {
  value = aws_cloudwatch_event_rule.scale_up.arn
}

output "scale_down_rule_arn" {
  value = aws_cloudwatch_event_rule.scale_down.arn
}
