data "aws_region" "main_region" {}

locals {
  is_testing = terraform.workspace == "testing"
  ha_enabled = local.is_testing ? "false" : "true"
  count      = local.is_testing ? 0 : 1
  aws_region = data.aws_region.main_region.name
}

provider "aws" {
  default_tags {
    tags = {
      HA = local.ha_enabled
    }
  }
}

module "Templates" {
  source = "./modules/Templates"
  template = {
    "ansible" : {
      "ansible_static_hosts" : "inventory/hosts.ini"
    },
    "kubernetes" : {
      "kubernetes_cluster_conf" : "init/cluster_conf.yaml",
      "kubernetes_join_node" : "templates/join_node.yaml.j2",
      "kubernetes_aws_vpc_cni_values" : "cni/values.yaml",
      "kubernetes_credential_provider_conf" : "kubelet/credential_provider_conf.yaml.j2"
    },
    "openvpn" : {
      "openvpn_client_conf" : "templates/client.ovpn.j2",
      "openvpn_server_conf" : "templates/server.conf"
    },
    "haproxy" : {
      "haproxy_conf" : "templates/haproxy.cfg.j2"
    }
  }
  parameters = {
    ec2_instances       = module.EC2.ec2_instances,
    tf_workspace        = terraform.workspace,
    domain_name         = var.domain_name,
    vpc_host            = cidrhost(var.vpc_cidr_block, 0),
    vpc_cidr_mask       = cidrnetmask(module.VPC.vpc_cidr_block),
    openvpn_subnet      = var.openvpn_subnet,
    openvpn_subnet_mask = cidrnetmask(var.openvpn_subnet),
    pwd                 = trimspace(var.pwd),
    aws_region          = local.aws_region
  }
}

module "Route53" {
  enabled     = local.count > 0
  source      = "./modules/Route53"
  domain_name = var.domain_name
  vpc_id      = module.VPC.vpc_id
}

module "Lambda" {
  enabled = local.count > 0
  source  = "./modules/Lambda"
  # List of functions with params
  function = {
    "haproxy_healthcheck" = {
      kubernetes_cluster_phase_name  = module.SSM.ssm_kubernetes_cluster_phase_name
      kubernetes_cluster_phase_value = module.SSM.ssm_kubernetes_cluster_phase_value
      route53_domain_name            = var.domain_name
      route53_hosted_zone            = module.Route53.route53_private_hosted_zone
      iam_role                       = module.IAM.iam_role_lambda_ha_proxy_healthcheck
      ec2_instances                  = module.EC2.ec2_instances
      vpc_subnet_map                 = module.VPC.vpc_subnet_map
      vpc_security_group             = module.VPC.vpc_security_groups
    }
  }
}

module "CloudWatch" {
  enabled = local.count > 0
  source  = "./modules/CloudWatch"
  # List of rules on Lambda functions
  function = {
    "haproxy_healthcheck" = {
      arn  = module.Lambda.lambda_haproxy_healthcheck_function_arn,
      name = module.Lambda.lambda_haproxy_healthcheck_function_name,
      rate = "rate(1 minute)"
    }
  }
}

module "EC2" {
  source = "./modules/EC2"

  # Instance configuration
  haproxy_instance_count = var.haproxy_instance_count
  haproxy_instance_type  = var.haproxy_instance_type

  controlplane_instance_count = var.controlplane_instance_count
  controlplane_instance_type  = var.controlplane_instance_type

  worker_instance_count = var.worker_instance_count
  worker_instance_type  = var.worker_instance_type

  # Network configuration
  networking = {
    vpc_cidr_block      = module.VPC.vpc_cidr_block
    vpc_subnet_map      = module.VPC.vpc_subnet_map
    vpc_security_groups = module.VPC.vpc_security_groups
  }

  # IAM configuration
  management = {
    iam_instance_profile = {
      "s3_full_access" : module.IAM.iam_ec2_instance_profile
    }
  }

}

module "VPC" {
  source  = "./modules/VPC"
  enabled = local.count > 0

  vpc_cidr_block  = var.vpc_cidr_block
  subnet_new_bits = 8

  private_subnet_net_numbers = [0, 1, 2]
  private_subnet_azs         = ["a", "b", "c"]

  public_subnet_net_numbers = [100, 101, 102]
  public_subnet_azs         = ["a", "b", "c"]
}

module "SSM" {
  enabled = local.count > 0
  source  = "./modules/SSM"
  parameters = {
    cluster_phase = var.build_phase
  }
}

module "IAM" {
  source = "./modules/IAM"
}


