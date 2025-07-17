resource "aws_ssm_parameter" "kubernetes_cluster_phase" {
  count = var.enabled ? 1 : 0
  name  = "/kubernetes/${terraform.workspace}/cluster_phase"
  type  = "String"
  value = var.parameters["cluster_phase"]
  tags = {
    department = terraform.workspace
  }
}
