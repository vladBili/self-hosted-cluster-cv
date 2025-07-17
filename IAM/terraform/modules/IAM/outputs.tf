output "iam_ec2_instance_profile" {
  value = aws_iam_instance_profile.iam_ec2_instance_profile.name
}

output "iam_role_lambda_ha_proxy_healthcheck" {
  value = aws_iam_role.iam_lambda_role.arn
}
