output "ssm_kubernetes_cluster_phase_name" {
  value = var.enabled ? aws_ssm_parameter.kubernetes_cluster_phase[0].name : null
}

output "ssm_kubernetes_cluster_phase_value" {
  value = var.enabled ? aws_ssm_parameter.kubernetes_cluster_phase[0].value : null
}
