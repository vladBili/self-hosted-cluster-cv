locals {
  private_subnet_length = length(keys(var.networking.vpc_subnet_map["private"]))
  public_subnet_length  = length(keys(var.networking.vpc_subnet_map["public"]))
}

data "aws_region" "main_region" {}

# AMI
data "aws_ami" "main_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["137112412989"]
}

# Key pair
resource "tls_private_key" "main_tls_key_pair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "main_aws_key_pair" {
  key_name   = "main_key_pair"
  public_key = tls_private_key.main_tls_key_pair.public_key_openssh
  tags = {
    department = terraform.workspace
  }
}

resource "local_file" "main_private_key" {
  content         = tls_private_key.main_tls_key_pair.private_key_pem
  filename        = abspath("${path.root}/../ansible/env/${terraform.workspace}/keys/key.pem")
  file_permission = "0600"
}

# Instances
resource "aws_instance" "main_bastion_nodes" {
  instance_type = "t2.micro"
  ami           = data.aws_ami.main_ami.id
  key_name      = aws_key_pair.main_aws_key_pair.key_name

  subnet_id              = keys(var.networking.vpc_subnet_map["public"])[0]
  vpc_security_group_ids = [var.networking.vpc_security_groups["bastion"]]

  iam_instance_profile = var.management.iam_instance_profile["s3_full_access"]

  tags = {
    Name                                                   = "bastion-0"
    department                                             = terraform.workspace
    "kubernetes.io/cluster/${terraform.workspace}-cluster" = "owned"
  }

  lifecycle {
    ignore_changes = [vpc_security_group_ids]
  }
}

resource "aws_eip" "main_bastion_ip" {
  domain = "vpc"
  tags = {
    Name       = "${terraform.workspace}-EIP for Bastion-${data.aws_region.main_region.name}",
    department = terraform.workspace
  }
}

resource "aws_eip_association" "main_bastion_eip_assoc" {
  instance_id   = aws_instance.main_bastion_nodes.id
  allocation_id = aws_eip.main_bastion_ip.id
}

resource "aws_instance" "main_haproxy_nodes" {
  count         = var.haproxy_instance_count
  instance_type = var.haproxy_instance_type
  ami           = data.aws_ami.main_ami.id
  key_name      = aws_key_pair.main_aws_key_pair.key_name

  subnet_id              = keys(var.networking.vpc_subnet_map["private"])[count.index % local.private_subnet_length]
  vpc_security_group_ids = [var.networking.vpc_security_groups["haproxy"]]

  iam_instance_profile = var.management.iam_instance_profile["s3_full_access"]

  tags = {
    Name                                                   = "haproxy-${count.index}"
    department                                             = terraform.workspace
    "kubernetes.io/cluster/${terraform.workspace}-cluster" = "owned"
  }

  lifecycle {
    ignore_changes = [vpc_security_group_ids]
  }

}

resource "aws_instance" "main_controlplane_nodes" {
  count         = var.controlplane_instance_count
  instance_type = var.controlplane_instance_type
  ami           = data.aws_ami.main_ami.id
  key_name      = aws_key_pair.main_aws_key_pair.key_name

  subnet_id              = keys(var.networking.vpc_subnet_map["private"])[count.index % local.private_subnet_length]
  vpc_security_group_ids = [var.networking.vpc_security_groups["controlplane"]]

  iam_instance_profile = var.management.iam_instance_profile["s3_full_access"]

  tags = {
    Name                                                   = "controlplane-${count.index}"
    department                                             = terraform.workspace
    "kubernetes.io/cluster/${terraform.workspace}-cluster" = "owned"
  }

  root_block_device {
    volume_size           = 20
    delete_on_termination = true
  }

  lifecycle {
    ignore_changes = [vpc_security_group_ids]
  }
}

resource "aws_instance" "main_worker_nodes" {
  count             = var.worker_instance_count
  instance_type     = var.worker_instance_type
  ami               = data.aws_ami.main_ami.id
  key_name          = aws_key_pair.main_aws_key_pair.key_name
  source_dest_check = false

  subnet_id              = keys(var.networking.vpc_subnet_map["private"])[count.index % local.private_subnet_length]
  vpc_security_group_ids = [var.networking.vpc_security_groups["worker"]]

  iam_instance_profile = var.management.iam_instance_profile["s3_full_access"]


  tags = {
    Name                                                   = "worker-${count.index}"
    department                                             = terraform.workspace
    "kubernetes.io/cluster/${terraform.workspace}-cluster" = "owned"
  }

  root_block_device {
    volume_size           = 20
    delete_on_termination = true
  }

  lifecycle {
    ignore_changes = [vpc_security_group_ids]
  }
}
