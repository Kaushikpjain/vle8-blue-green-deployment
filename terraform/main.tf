terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

variable "cloudshell_ip" {
  description = "Current CloudShell public IP"
  type        = string
}

data "aws_vpc" "selected" {
  id = "vpc-0ba7fad6628f8a90f"
}

data "aws_subnet" "selected" {
  id = "subnet-02f3317103c9dc5c4"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "vle8" {
  name        = "vle8-blue-green-sg"
  description = "VLE-8 Blue Green Deployment server"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    description = "SSH from CloudShell"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.cloudshell_ip}/32"]
  }

  ingress {
    description     = "SSH from VLE-6 Jenkins"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = ["sg-0df3511e64f3ed04b"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "VLE8-BlueGreen-SG"
    Experiment  = "VLE-8"
    Environment = "DevOps-Lab"
  }
}

resource "aws_instance" "vle8" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.small"
  subnet_id                   = data.aws_subnet.selected.id
  key_name                    = "vle5-devops-key"
  vpc_security_group_ids      = [aws_security_group.vle8.id]
  associate_public_ip_address = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name        = "VLE8-BlueGreen-Server"
    Experiment  = "VLE-8"
    Environment = "DevOps-Lab"
  }
}

output "instance_id" {
  value = aws_instance.vle8.id
}

output "public_ip" {
  value = aws_instance.vle8.public_ip
}

output "private_ip" {
  value = aws_instance.vle8.private_ip
}

output "security_group_id" {
  value = aws_security_group.vle8.id
}
