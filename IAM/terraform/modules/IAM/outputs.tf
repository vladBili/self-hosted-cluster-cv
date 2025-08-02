output "iam_ec2_instance_profile" {
  value = {
    for role, value in aws_iam_instance_profile.iam_ec2_instance_profile :
    role => value.name
  }
}

output "iam_role_lambda_ha_proxy_healthcheck" {
  value = aws_iam_role.iam_lambda_role.arn
}

output "iam_irsa_role_arn" {
  value = {
    for role, value in aws_iam_role.iam_irsa_role :
    role => value.arn
  }
}
