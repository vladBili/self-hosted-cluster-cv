data "aws_region" "main_region" {}

resource "aws_cloudwatch_event_rule" "main_rule_haproxy_healthcheck_schedule" {
  count               = var.enabled ? 1 : 0
  name                = "haproxy_healthcheck_schedule"
  schedule_expression = "rate(1 minute)"
  tags = {
    Name       = "${terraform.workspace}-haproxy_healthcheck_schedule-${data.aws_region.main_region.name}"
    department = terraform.workspace
  }
}

resource "aws_cloudwatch_event_target" "main_target_haproxy_healthcheck_schedule" {
  count     = var.enabled ? 1 : 0
  rule      = aws_cloudwatch_event_rule.main_rule_haproxy_healthcheck_schedule[count.index].name
  target_id = "ScheduleLambdaFunction"
  arn       = var.function["haproxy_healthcheck"].arn
}

resource "aws_lambda_permission" "allow_eventbridge_invoke_lambda_function" {
  count         = var.enabled ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = var.function["haproxy_healthcheck"].name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.main_rule_haproxy_healthcheck_schedule[count.index].arn
}

