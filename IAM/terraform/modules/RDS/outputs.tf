output "airflow_db_connection" {
  value     = try("postgresql+psycopg2://${aws_db_instance.main_rds_db["airflow"].username}:${aws_db_instance.main_rds_db["airflow"].password}@${aws_db_instance.main_rds_db["airflow"].address}:${aws_db_instance.main_rds_db["airflow"].port}/${aws_db_instance.main_rds_db["airflow"].db_name}?sslmode=require", null)
  sensitive = true
}
