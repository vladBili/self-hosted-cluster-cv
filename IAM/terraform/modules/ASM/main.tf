resource "aws_secretsmanager_secret" "asm_airflow_rds_connection" {
  name = "airflow_rds_connection"
}

resource "aws_secretsmanager_secret_version" "asm_airflow_connection" {
  secret_id     = aws_secretsmanager_secret.asm_airflow_rds_connection.id
  secret_string = var.asm_dict["airflow_conn"]
}






