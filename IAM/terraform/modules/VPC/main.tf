locals {
  private_subnet_length = length(var.private_subnet_net_numbers)
  public_subnet_length  = length(var.public_subnet_net_numbers)

  instance_groups = { for group in ["controlplane", "haproxy", "worker", "bastion"] : group => group }

  bastion_public_ingress_rules = merge(var.ssh_ingress_security_group, var.bastion_ingress_security_group)
  bastion_public_ingress_keys  = keys(local.bastion_public_ingress_rules)

  haproxy_private_ingress_rules = merge(var.ssh_ingress_security_group, var.haproxy_ingress_security_group, var.web_ingress_security_group)
  haproxy_private_ingress_keys  = keys(local.haproxy_private_ingress_rules)

  controlplane_private_ingress_rules = merge(var.ssh_ingress_security_group, var.kubernetes_ingress_security_group, var.web_ingress_security_group, var.controlplane_ingress_security_group)
  controlplane_private_ingress_keys  = keys(local.controlplane_private_ingress_rules)

  worker_private_ingress_rules = merge(var.ssh_ingress_security_group, var.kubernetes_ingress_security_group, var.web_ingress_security_group)
  worker_private_ingress_keys  = keys(local.worker_private_ingress_rules)
}

data "aws_region" "main_region" {}

# VPC
resource "aws_vpc" "main_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name       = "${terraform.workspace}-VPC-${data.aws_region.main_region.name}",
    department = terraform.workspace
  }
}

# Private Subnet
resource "aws_subnet" "main_private_subnets" {
  count      = local.private_subnet_length
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = cidrsubnet(var.vpc_cidr_block, var.subnet_new_bits, var.private_subnet_net_numbers[count.index])
  tags = {
    Name                                                   = "${terraform.workspace}-Private-Subnet-${count.index}-${data.aws_region.main_region.name}",
    department                                             = terraform.workspace
    "kubernetes.io/cluster/${terraform.workspace}-cluster" = "owned"
    "kubernetes.io/role/internal-elb"                      = 1
  }
  availability_zone = "${data.aws_region.main_region.name}${var.private_subnet_azs[count.index]}"
}

# Public Subnet
resource "aws_subnet" "main_public_subnets" {
  count      = local.public_subnet_length
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = cidrsubnet(var.vpc_cidr_block, var.subnet_new_bits, var.public_subnet_net_numbers[count.index])
  tags = {
    name                                                   = "${terraform.workspace}-Public-Subnet-${count.index}-${data.aws_region.main_region.name}",
    department                                             = terraform.workspace
    "kubernetes.io/cluster/${terraform.workspace}-cluster" = "owned"
    "kubernetes.io/role/elb"                               = 1
  }
  availability_zone = "${data.aws_region.main_region.name}${var.public_subnet_azs[count.index]}"
}

# IGW
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name       = "${terraform.workspace}-IGW-${data.aws_region.main_region.name}",
    department = terraform.workspace
  }
}

# NAT
resource "aws_nat_gateway" "main_nat" {
  subnet_id     = aws_subnet.main_public_subnets[0].id
  allocation_id = aws_eip.main_nat_ip.id

  tags = {
    Name       = "${terraform.workspace}-NAT-${data.aws_region.main_region.name}"
    department = terraform.workspace
  }

  depends_on = [aws_internet_gateway.main_igw]
}

resource "aws_eip" "main_nat_ip" {
  domain = "vpc"
  tags = {
    Name       = "${terraform.workspace}-EIP for NAT-${data.aws_region.main_region.name}",
    department = terraform.workspace
  }
}

# Public subnet RT -> IGW
resource "aws_route_table" "main_public_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = aws_vpc.main_vpc.cidr_block
    gateway_id = "local"
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name                                                   = "${terraform.workspace}-Public-RT-${data.aws_region.main_region.name}",
    department                                             = terraform.workspace
    "kubernetes.io/cluster/${terraform.workspace}-cluster" = "owned"
  }
}

resource "aws_route_table_association" "public_subnet_association" {
  count          = local.public_subnet_length
  subnet_id      = aws_subnet.main_public_subnets[count.index].id
  route_table_id = aws_route_table.main_public_route_table.id
}

# Private subnet RT -> NAT
resource "aws_route_table" "main_private_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = aws_vpc.main_vpc.cidr_block
    gateway_id = "local"
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.main_nat.id
  }

  tags = {
    Name                                                   = "${terraform.workspace}-Private-RT-${data.aws_region.main_region.name}",
    department                                             = terraform.workspace
    "kubernetes.io/cluster/${terraform.workspace}-cluster" = "shared"
  }
}

resource "aws_route_table_association" "private_subnet_association" {
  count          = local.private_subnet_length
  subnet_id      = aws_subnet.main_private_subnets[count.index].id
  route_table_id = aws_route_table.main_private_route_table.id
}


# SG
resource "aws_security_group" "main_security_group" {
  for_each = local.instance_groups
  vpc_id   = aws_vpc.main_vpc.id

  tags = {
    Name                                                   = "${terraform.workspace}-SG-${each.key}-${data.aws_region.main_region.name}",
    department                                             = terraform.workspace
    "kubernetes.io/cluster/${terraform.workspace}-cluster" = "owned"
  }
}

# SG ingress rules
resource "aws_vpc_security_group_ingress_rule" "main_controlplane_private_security_group_ingress_rule" {
  count             = length(local.controlplane_private_ingress_keys)
  security_group_id = aws_security_group.main_security_group["controlplane"].id
  cidr_ipv4         = aws_vpc.main_vpc.cidr_block
  from_port         = local.controlplane_private_ingress_rules[local.controlplane_private_ingress_keys[count.index]].from_port
  to_port           = local.controlplane_private_ingress_rules[local.controlplane_private_ingress_keys[count.index]].to_port
  ip_protocol       = local.controlplane_private_ingress_rules[local.controlplane_private_ingress_keys[count.index]].ip_protocol
  tags = {
    Name       = "${local.controlplane_private_ingress_keys[count.index]}",
    department = terraform.workspace
  }
}


resource "aws_vpc_security_group_ingress_rule" "main_worker_private_security_group_ingress_rule" {
  count             = length(local.worker_private_ingress_keys)
  security_group_id = aws_security_group.main_security_group["worker"].id
  cidr_ipv4         = aws_vpc.main_vpc.cidr_block
  from_port         = local.worker_private_ingress_rules[local.worker_private_ingress_keys[count.index]].from_port
  to_port           = local.worker_private_ingress_rules[local.worker_private_ingress_keys[count.index]].to_port
  ip_protocol       = local.worker_private_ingress_rules[local.worker_private_ingress_keys[count.index]].ip_protocol
  tags = {
    Name       = "${local.worker_private_ingress_keys[count.index]}",
    department = terraform.workspace
  }
}

resource "aws_vpc_security_group_ingress_rule" "main_haproxy_private_security_group_ingress_rule" {
  count             = length(local.haproxy_private_ingress_keys)
  security_group_id = aws_security_group.main_security_group["haproxy"].id
  cidr_ipv4         = aws_vpc.main_vpc.cidr_block
  from_port         = local.haproxy_private_ingress_rules[local.haproxy_private_ingress_keys[count.index]].from_port
  to_port           = local.haproxy_private_ingress_rules[local.haproxy_private_ingress_keys[count.index]].to_port
  ip_protocol       = local.haproxy_private_ingress_rules[local.haproxy_private_ingress_keys[count.index]].ip_protocol
  tags = {
    Name       = "${local.haproxy_private_ingress_keys[count.index]}",
    department = terraform.workspace
  }
}

resource "aws_vpc_security_group_ingress_rule" "main_bastion_public_security_group_ingress_rule" {
  count             = length(local.bastion_public_ingress_keys)
  security_group_id = aws_security_group.main_security_group["bastion"].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = local.bastion_public_ingress_rules[local.bastion_public_ingress_keys[count.index]].from_port
  to_port           = local.bastion_public_ingress_rules[local.bastion_public_ingress_keys[count.index]].to_port
  ip_protocol       = local.bastion_public_ingress_rules[local.bastion_public_ingress_keys[count.index]].ip_protocol
  tags = {
    Name       = "${local.bastion_public_ingress_keys[count.index]}",
    department = terraform.workspace
  }
}

resource "aws_vpc_security_group_egress_rule" "main_nodes_security_group_egress_rule" {
  for_each          = local.instance_groups
  security_group_id = aws_security_group.main_security_group[each.key].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}





