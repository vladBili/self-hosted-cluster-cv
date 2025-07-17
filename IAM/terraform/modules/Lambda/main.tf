data "archive_file" "haproxy_health_zip" {
  count       = var.enabled ? 1 : 0
  type        = "zip"
  source_dir  = "${path.root}/../python/env/${terraform.workspace}/ha_proxy_health"
  output_path = "${path.module}/python/function.zip"
}

resource "aws_lambda_function" "lambda_haproxy_health_function" {
  count            = var.enabled ? 1 : 0
  filename         = data.archive_file.haproxy_health_zip[count.index].output_path
  source_code_hash = data.archive_file.haproxy_health_zip[count.index].output_base64sha256
  function_name    = "ha_proxy_health"
  handler          = "function.lambda_handler"
  runtime          = "python3.13"
  role             = try(var.function["haproxy_healthcheck"].iam_role, "")
  timeout          = 30
  environment {
    variables = {
      CLUSTER_PHASE = try(var.function["haproxy_healthcheck"].kubernetes_cluster_phase_value, "")
      PRIMARY_IP    = try(var.function["haproxy_healthcheck"].ec2_instances["haproxy"]["haproxy-0"].private_ip, "")
      SECONDARY_IP  = try(var.function["haproxy_healthcheck"].ec2_instances["haproxy"]["haproxy-1"].private_ip, "")
      HOSTED_ZONE   = try(var.function["haproxy_healthcheck"].route53_hosted_zone, "")
      RECORD_NAME   = try("k8s.${var.function["haproxy_healthcheck"].route53_domain_name}", "")
      WORKSPACE     = "${terraform.workspace}"
    }
  }

  vpc_config {
    subnet_ids         = keys(var.function["haproxy_healthcheck"].vpc_subnet_map["private"])
    security_group_ids = [var.function["haproxy_healthcheck"].vpc_security_group["controlplane"]]
  }

  depends_on = [null_resource.ssm_dependency]
  tags = {
    department = terraform.workspace
  }
}

resource "null_resource" "ssm_dependency" {
  count = var.enabled ? 1 : 0
  triggers = {
    ssm_param = var.function["haproxy_healthcheck"].kubernetes_cluster_phase_name
  }
}

