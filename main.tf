provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "my-vpc-01" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "main"
  }
}

resource "aws_subnet" "my-public-01" {
  vpc_id     = aws_vpc.my-vpc-01.id
  cidr_block = "10.0.1.0/24"
  

  tags = {
    Name = "Main01"
  }
}

resource "aws_subnet" "my-public-02" {
  vpc_id     = aws_vpc.my-vpc-01.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "Main02"
  }
}

resource "aws_internet_gateway" "int-gt-01" {
  vpc_id = aws_vpc.my-vpc-01.id
}

# 4. Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.my-vpc-01.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.int-gt-01.id
  }
}

# 5. Associate Route Table with Public Subnets
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.my-public-01.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.my-public-02.id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "my-private-01" {
  vpc_id     = aws_vpc.my-vpc-01.id
  cidr_block = "10.0.101.0/24"

  tags = {
    Name = "Main03"
  }
}

resource "aws_subnet" "my-private-02" {
  vpc_id     = aws_vpc.my-vpc-01.id
  cidr_block = "10.0.102.0/24"

  tags = {
    Name = "Main04"
  }
}

#====================================================

resource "aws_route_table" "private-rt-01" {
  vpc_id = aws_vpc.my-vpc-01.id

  tags = {
    Name = "private-route-table-01"
  }
}

resource "aws_eip" "eip-01" {
  domain = "vpc"
}

resource "aws_nat_gateway" "private-nat-01" {
  allocation_id = aws_eip.eip-01.id
  subnet_id     = aws_subnet.my-private-01.id

  tags = {
    Name = "gw NAT01"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.int-gt-01]
}

resource "aws_route" "private-nat-route-01" {
  route_table_id         = aws_route_table.private-rt-01.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.private-nat-01.id
}

resource "aws_route_table_association" "private_assoc-01" {
  subnet_id      = aws_subnet.my-private-01.id
  route_table_id = aws_route_table.private-rt-01.id
}

resource "aws_route_table" "private-rt-02" {
  vpc_id = aws_vpc.my-vpc-01.id

  tags = {
    Name = "private-route-table-02"
  }
}

resource "aws_eip" "eip-02" {
  domain = "vpc"
}


resource "aws_nat_gateway" "private-nat-02" {
  allocation_id = aws_eip.eip-02.id
  subnet_id     = aws_subnet.my-private-02.id

  tags = {
    Name = "gw NAT02"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.int-gt-01]
}

resource "aws_route" "private-nat-route-02" {
  route_table_id         = aws_route_table.private-rt-02.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.private-nat-02.id
}

resource "aws_route_table_association" "private_assoc-02" {
  subnet_id      = aws_subnet.my-private-02.id
  route_table_id = aws_route_table.private-rt-02.id
}


resource "aws_security_group" "public-sec-01" {
  vpc_id      = aws_vpc.my-vpc-01.id
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4" {
  security_group_id = aws_security_group.public-sec-01.id
  cidr_ipv4         = aws_vpc.main.cidr_block
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.public-sec-01.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}