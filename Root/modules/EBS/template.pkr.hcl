packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = ">= 1.4.0"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = ">= 1.1.4"
    }
  }
}

variable "vpc_id" {
  type    = string
}

variable "subnet_id" {
  type    = string
}

variable "region" {
  type    = string
}

variable "profile" {
  type    = string
}

variable "department" {
  type = string
  default = "production"
}

variable "pwd" {
  type = string
  default = "production"
}

variable "credential_provider" {
  type = string
  default = "true"
}

variable "domain_name" {
  type = string
}

source "amazon-ebs" "ami_type" {
  profile       = "root"
  vpc_id        = var.vpc_id
  subnet_id     = var.subnet_id
  region        = var.region
  source_ami    = "ami-090a27e0710d8ef71"
  instance_type = "t3.small"
  ssh_username  = "ec2-user"
  ami_name      = "aws-linux-production-cv-project-vlad-bilii"
}

build {
    sources = [
        "source.amazon-ebs.ami_type"
    ]

    provisioner "ansible" {
      playbook_file = "../../../IAM/ansible/playbook/02-playbook-init.yaml"
      extra_arguments = [
        "--tags", "packer",
        "--extra-vars", "DEPARTMENT=${var.department} DIRECTORY=${var.pwd} REGION=${var.region} CREDENTIAL_PROVIDER=${var.credential_provider} DOMAIN_NAME=${var.domain_name} PACKER_AMI_BUILD=true"
      ]

    }
}
