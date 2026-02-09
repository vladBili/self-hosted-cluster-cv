variable "vpc_cidr_block" {
  type = string
}

variable "subnet_new_bits" {
  type = number
}

variable "private_subnet_net_numbers" {
  type = list(number)
}

variable "private_subnet_azs" {
  type = list(string)
}

variable "public_subnet_net_numbers" {
  type = list(number)
}

variable "public_subnet_azs" {
  type = list(string)
}

variable "kubernetes_ingress_security_group" {
  type = map(object({
    from_port = number,
    to_port   = number,
    ip_protocol = string }
  ))
  default = {
    "kubelet_tcp" = {
      from_port   = 10250,
      to_port     = 10250,
      ip_protocol = "tcp"
    },
    "ping_icmp" = {
      from_port   = -1,
      to_port     = -1,
      ip_protocol = "icmp"
    },
    "coredns_udp" = {
      from_port   = 53,
      to_port     = 53,
      ip_protocol = "udp"
    },
    "coredns_tcp" = {
      from_port   = 53,
      to_port     = 53,
      ip_protocol = "tcp"
    },
    "coredns_metrics_tcp" = {
      from_port   = 9153,
      to_port     = 9153,
      ip_protocol = "tcp"
    },
    "nodeport_tcp" = {
      from_port   = 30000,
      to_port     = 65535,
      ip_protocol = "tcp"
    },
    "nodeport_udp" = {
      from_port   = 30000,
      to_port     = 65535,
      ip_protocol = "udp"
    },
    "redis_tcp" = {
      from_port   = 6379,
      to_port     = 6379,
      ip_protocol = "tcp"
    },
    "argo_tcp" = {
      from_port   = 8081,
      to_port     = 8081,
      ip_protocol = "tcp"
    },
    "sentinel_tcp" = {
      from_port   = 26379,
      to_port     = 26379,
      ip_protocol = "tcp"
    },
    "nginx_webhook_tcp" = {
      from_port   = 8443,
      to_port     = 8443,
      ip_protocol = "tcp"
    },
    "postgres_tcp" = {
      from_port   = 5432,
      to_port     = 5432,
      ip_protocol = "tcp"
    },
    "spark-operator" = {
      from_port   = 9443,
      to_port     = 9443,
      ip_protocol = "tcp"
    }
  }
}

variable "web_ingress_security_group" {
  type = map(object({
    from_port = number,
    to_port   = number,
    ip_protocol = string }
  ))
  default = {
    "http_tcp" = {
      from_port   = 80,
      to_port     = 80,
      ip_protocol = "tcp"
    },
    "https_tcp" = {
      from_port   = 443,
      to_port     = 443,
      ip_protocol = "tcp"
    },
    "haproxy_healthcheck_tcp" = {
      from_port   = 8080,
      to_port     = 8080,
      ip_protocol = "tcp"
    }
  }
}

variable "ssh_ingress_security_group" {
  type = map(object({
    from_port = number,
    to_port   = number,
    ip_protocol = string }
  ))
  default = {
    "ssh_tcp" = {
      from_port   = 22,
      to_port     = 22,
      ip_protocol = "tcp"
    }
  }
}

variable "controlplane_ingress_security_group" {
  type = map(object({
    from_port = number,
    to_port   = number,
    ip_protocol = string }
  ))
  default = {
    "apiserver_tcp" = {
      from_port   = 6443,
      to_port     = 6443,
      ip_protocol = "tcp"
    },
    "etcd_tcp" = {
      from_port   = 2379,
      to_port     = 2380,
      ip_protocol = "tcp"
    },
    "controller_webhook_tcp" = {
      from_port   = 9443,
      to_port     = 9443,
      ip_protocol = "tcp"
    }
  }
}

variable "bastion_ingress_security_group" {
  type = map(object({
    from_port = number,
    to_port   = number,
    ip_protocol = string }
  ))
  default = {
    "openvpn_tcp" = {
      from_port   = 1194,
      to_port     = 1194,
      ip_protocol = "tcp"
    },
    "openvpn_udp" = {
      from_port   = 1194,
      to_port     = 1194,
      ip_protocol = "udp"
    }
  }
}

variable "rds_ingress_security_group" {
  type = map(object({
    from_port = number,
    to_port   = number,
    ip_protocol = string }
  ))
  default = {
    "postgres_tcp" = {
      from_port   = 5432,
      to_port     = 5432,
      ip_protocol = "tcp"
    }
  }
}

variable "haproxy_ingress_security_group" {
  type = map(object({
    from_port = number,
    to_port   = number,
    ip_protocol = string }
  ))
  default = {
    "apiserver_tcp" = {
      from_port   = 6443,
      to_port     = 6443,
      ip_protocol = "tcp"
    }
  }
}

variable "enabled" {
  type = bool
}
