resource "aws_route53_zone" "private" {
  count = var.enabled ? 1 : 0
  name  = var.domain_name

  vpc {
    vpc_id = var.vpc_id
  }

  lifecycle {
    ignore_changes = [vpc]
  }
  tags = {
    department = terraform.workspace
  }
}


