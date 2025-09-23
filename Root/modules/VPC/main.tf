resource "aws_vpc" "packer_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "packer_igw" {
  vpc_id = aws_vpc.packer_vpc.id
}

resource "aws_subnet" "packer_subnet" {
  vpc_id                  = aws_vpc.packer_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_route_table" "packer_rt" {
  vpc_id = aws_vpc.packer_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.packer_igw.id
  }
}

resource "aws_route_table_association" "packer_rta" {
  subnet_id      = aws_subnet.packer_subnet.id
  route_table_id = aws_route_table.packer_rt.id
}
