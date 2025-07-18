vpc_cidr_block = "10.0.0.0/16"
openvpn_subnet = "10.0.5.0/24"
domain_name    = "vladbilii.click"

haproxy_instance_count = 2
haproxy_instance_type  = "t2.micro"

controlplane_instance_count = 2
controlplane_instance_type  = "t3.small"

worker_instance_count = 1
worker_instance_type  = "t3.small"
