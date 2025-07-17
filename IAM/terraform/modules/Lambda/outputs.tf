output "lambda_haproxy_healthcheck_function_arn" {
  value = var.enabled ? aws_lambda_function.lambda_haproxy_health_function[0].arn : null
}

output "lambda_haproxy_healthcheck_function_name" {
  value = var.enabled ? aws_lambda_function.lambda_haproxy_health_function[0].function_name : null
}

