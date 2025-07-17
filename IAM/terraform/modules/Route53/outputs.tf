output "route53_private_hosted_zone" {
  value = var.enabled ? aws_route53_zone.private[0].zone_id : null
}
