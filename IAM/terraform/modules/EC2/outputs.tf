output "ec2_instances" {
  value = {
    "bastion" = {
      "bastion-0" = {
        private_ip  = aws_instance.main_bastion_nodes.private_ip,
        public_ip   = aws_eip.main_bastion_ip.public_ip,
        private_dns = aws_instance.main_bastion_nodes.private_dns
      }
    }

    "haproxy" = {
      for key, value in aws_instance.main_haproxy_nodes :
      value.tags["Name"] => {
        private_ip  = value.private_ip,
        public_ip   = value.public_ip,
        private_dns = value.private_dns
      }
    }

    "controlplane" = {
      for key, value in aws_instance.main_controlplane_nodes :
      value.tags["Name"] => {
        private_ip  = value.private_ip,
        public_ip   = value.public_ip,
        private_dns = value.private_dns
      }
    }

    "worker" = {
      for key, value in aws_instance.main_worker_nodes :
      value.tags["Name"] => {
        private_ip  = value.private_ip,
        public_ip   = value.public_ip,
        private_dns = value.private_dns
      }
    }
  }
}

