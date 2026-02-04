resource "aws_secretsmanager_secret" "asm_airflow_rds_connection" {
  count = var.enabled ? 1 : 0
  name  = "airflow/${terraform.workspace}/rds_connection"
}

resource "aws_secretsmanager_secret" "asm_gitlab_runner_token" {
  name = "gitlab/${terraform.workspace}/runner_token"
}

resource "aws_secretsmanager_secret_version" "asm_airflow_rds_connection_version" {
  count         = var.enabled ? 1 : 0
  secret_id     = aws_secretsmanager_secret.asm_airflow_rds_connection[0].id
  secret_string = var.asm_dict["airflow_conn"]
}

resource "aws_secretsmanager_secret_version" "asm_gitlab_runner_token_version" {
  secret_id     = aws_secretsmanager_secret.asm_gitlab_runner_token.id
  secret_string = " "
}


