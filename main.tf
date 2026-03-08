terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.30.0"
    }
  }
}
provider "aws" {
  region = "us-east-1"
}
//--------------------------
locals {
  vpc_cidr = "172.16.1.0/24"
}
data "aws_availability_zones" "az" {
  state = "available"
}
resource "aws_vpc" "main" {
  cidr_block = local.vpc_cidr
}

resource "aws_subnet" "main" {
  for_each          = toset(data.aws_availability_zones.az.names)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(local.vpc_cidr, 3, index(data.aws_availability_zones.az.names, each.key))
  availability_zone = each.key
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "myvpc"
  }
}
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}
resource "aws_route_table_association" "main" {
  for_each       = aws_subnet.main
  subnet_id      = each.value.id
  route_table_id = aws_route_table.main.id
}
locals {
  ports = {
    ssh = {
      fport    = 22
      protocol = "Tcp"
      cidr     = ["192.168.1.0/24"]
    }
    http = {
      fport    = 80
      protocol = "Tcp"
      cidr     = ["0.0.0.0/0"]
    }
  }
}
resource "aws_security_group" "main" {
  vpc_id = aws_vpc.main.id
  dynamic "ingress" {
    for_each = local.ports
    content {
      from_port   = ingress.value.fport
      to_port     = ingress.value.fport
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "Tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_key_pair" "main" {
  key_name   = "ubuntu"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC5QqtH1y7NC/jJ8pOGzeQ90n8XuESQ+JMQovkhS/CFdGeh2Il0KDgFWvbxrkVUlnPEHCSTKEm92jLXfhlzGxX/5KSgkzRAgOQpsCP29nvjcFMVoyErcVen0KrQmhf7njg92lQIEyymNGNhd8b5gONXxHd0PpsOMT5wtvt9CZoN8aJu32+JT844xljp9tyirgptyJQdcjqb/rNKPh5vrRcPF4gRcQEMXRtLiXJfZ6Mg67/rLYO6oDrZSApG5oyS+JZx/g/mEuGeeVkOF+Ivc8Iq0AiWewJrjb/8e93lH14x5LaURkhZmRKIQfk7Fg5BRzIgboJBf8MvEDsBoftaOx2r vijay@virus"
}
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server*"]
  }
}

resource "aws_instance" "main" {
  instance_type               = "t2.micro"
  subnet_id                   = values(aws_subnet.main)[0].id
  ami                         = data.aws_ami.ubuntu.id
  vpc_security_group_ids      = [aws_security_group.main.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.main.key_name
}
output "ec2_ip" {
  value = aws_instance.main.public_ip
}

output "subnets-data" {
  value = values(aws_subnet.main)[0].id
}
