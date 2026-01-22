resource "random_password" "airflow_password" {
  length           = 16
  special          = true
  override_special = "!#$%^&*()-_=+[]{}<>:?" # exclude / @ " and space
}

resource "aws_db_subnet_group" "main_db_subnet_group" {
  for_each   = var.rds_dict
  name       = "main_${each.key}_rds_subnet_group"
  subnet_ids = keys(var.rds_dict[each.key].subnets)
  tags = {
    Name       = "${each.key}-db-subnet-group"
    department = terraform.workspace
  }
}

resource "aws_db_instance" "main_rds_db" {
  for_each          = var.rds_dict
  identifier        = "main-${each.key}-rds-db"
  engine            = var.rds_dict[each.key].engine
  engine_version    = var.rds_dict[each.key].engine_version
  instance_class    = var.rds_dict[each.key].instance_class
  allocated_storage = var.rds_dict[each.key].allocated_storage
  storage_type      = var.rds_dict[each.key].storage_type

  db_name  = var.rds_dict[each.key].db_username
  username = var.rds_dict[each.key].db_username
  password = random_password.airflow_password.result
  port     = var.rds_dict[each.key].db_port

  multi_az            = var.rds_dict[each.key].multi_az
  publicly_accessible = var.rds_dict[each.key].publicly_accessible
  skip_final_snapshot = var.rds_dict[each.key].skip_final_snapshot

  vpc_security_group_ids = [var.rds_dict[each.key].security_groups]
  db_subnet_group_name   = aws_db_subnet_group.main_db_subnet_group[each.key].name

  tags = {
    Name       = "${each.key}-rds"
    department = terraform.workspace
  }
}
