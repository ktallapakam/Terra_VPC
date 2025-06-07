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


resource "aws_security_group" "sec-01" {
  name        = "sec-01"
  description = "Allow SSH and HTTP"
  vpc_id      = aws_vpc.my-vpc-01.id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Caution: Open to all
  }

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "ssm_role" {
  name = "ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "ssm-instance-profile"
  role = aws_iam_role.ssm_role.name
}

resource "aws_instance" "docker_host" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.my-public-01.id
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.sec-01.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_instance_profile.name
  key_name               = "Terra"

  tags = {
    Name = "DockerHostViaSSM"
  }
}


resource "aws_ssm_document" "install_docker_script" {
  name          = "InstallDocker"
  document_type = "Command"

  content = jsonencode({
    schemaVersion = "2.2",
    description   = "Install Docker on Ubuntu EC2",
    mainSteps = [
      {
        action = "aws:runShellScript",
        name   = "installDocker",
        inputs = {
          runCommand = [
            "sudo apt-get update",
            "sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common",
            "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -",
            "sudo add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\"",
            "sudo apt-get update",
            "sudo apt-get install -y docker-ce",
            "sudo usermod -aG docker ubuntu",
            "sudo systemctl enable docker",
            "sudo systemctl start docker"
          ]
        }
      }
    ]
  })
}

resource "aws_ssm_association" "run_install_docker" {
  name       = aws_ssm_document.install_docker_script.name

  targets {
    key    = "InstanceIds"
    values = [aws_instance.docker_host.id]
  }

  depends_on = [aws_instance.docker_host]
}


data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

output "docker_host_public_ip" {
  description = "Public IP of the Docker host EC2 instance"
  value       = aws_instance.docker_host.public_ip
}


