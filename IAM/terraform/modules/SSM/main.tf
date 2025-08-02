locals {
  irsa_enabled = aws_ssm_parameter.kubernetes_cluster_phase.value == "postinit"
}

resource "aws_ssm_parameter" "kubernetes_cluster_phase" {
  name  = "/kubernetes/${terraform.workspace}/cluster_phase"
  type  = "String"
  value = var.parameters["cluster_phase"]
  tags = {
    department = terraform.workspace
  }
}

resource "aws_ssm_parameter" "oidc_thumbprint" {
  name  = "/oidc/${terraform.workspace}/thumbprint"
  type  = "String"
  value = local.irsa_enabled ? var.parameters["oidc_thumbprint"] : " "
  tags = {
    department = terraform.workspace
  }
}

resource "aws_ssm_parameter" "kubernetes_irsa_arns" {
  for_each = var.parameters["iam_irsa_arn"]
  name     = "/kubernetes/${terraform.workspace}/${each.key}"
  type     = "String"
  value    = local.irsa_enabled ? each.value : " "
  tags = {
    department = terraform.workspace
  }
}
