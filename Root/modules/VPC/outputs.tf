output "packer_vpc" {
  value = {
    vpc_id    = aws_vpc.packer_vpc.id
    subnet_id = aws_subnet.packer_subnet.id
  }
}
