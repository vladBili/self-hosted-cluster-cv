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

variable "networking" {
  type = object({
    vpc_cidr_block = string
    vpc_subnet_map = map(map(object({
      CIDR = string
      AZ   = string
    })))
    vpc_security_groups = map(string)
  })
}


variable "management" {
}
