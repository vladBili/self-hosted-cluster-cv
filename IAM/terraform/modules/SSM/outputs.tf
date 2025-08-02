output "ssm_kubernetes_cluster_phase_name" {
  value = var.enabled ? aws_ssm_parameter.kubernetes_cluster_phase.name : null
}

output "ssm_kubernetes_cluster_phase_value" {
  value = var.enabled ? aws_ssm_parameter.kubernetes_cluster_phase.value : null
}

output "ssm_oidc_thumbprint" {
  value = var.enabled && length(aws_ssm_parameter.oidc_thumbprint) > 0 ? aws_ssm_parameter.oidc_thumbprint.value : null
}
