output "vpc_cidr_block" {
  value = aws_vpc.main_vpc.cidr_block
}

output "vpc_id" {
  value = aws_vpc.main_vpc.id
}

output "vpc_subnet_map" {
  value = merge(
    { "private" = { for key, value in aws_subnet.main_private_subnets :
      value.id => { "CIDR" : value.id, "AZ" : value.availability_zone }
      },
      "public" = { for key, value in aws_subnet.main_public_subnets :
        value.id => { "CIDR" : value.id, "AZ" : value.availability_zone }
      }
    }
  )
}

output "vpc_security_groups" {
  value = { for key, value in aws_security_group.main_security_group :
  key => value.id }
}
