variable "haproxy_instance_count" {
  type = number
}

variable "haproxy_instance_type" {
  type = string
}

variable "controlplane_instance_count" {
  type = number
}

variable "controlplane_instance_type" {
  type = string
}

variable "worker_instance_count" {
  type = number
}

variable "worker_instance_type" {
  type = string
}

variable "openvpn_subnet" {
  type = string
}

variable "domain_name" {
  type    = string
  default = "vladbilii.click"
}

variable "vpc_cidr_block" {
  type = string
}

variable "pwd" {
  type = string
}

variable "build_phase" {
  type = string
}
