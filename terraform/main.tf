terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Security Group
resource "aws_security_group" "kredar_sg" {
  name        = "kredar-sg"
  description = "Allow HTTP, HTTPS, SSH and API traffic"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Kredar API"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "kredar-sg"
  }
}

# Key Pair
resource "aws_key_pair" "kredar_key" {
  key_name   = "kredar-key"
  public_key = file(var.public_key_path)
}

# EC2 Instance
resource "aws_instance" "kredar_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.kredar_key.key_name
  vpc_security_group_ids = [aws_security_group.kredar_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y docker.io docker-compose-v2 git
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ubuntu
  EOF

  tags = {
    Name = "kredar-server"
  }
}

# Elastic IP (static public IP)
resource "aws_eip" "kredar_eip" {
  instance = aws_instance.kredar_server.id
  domain   = "vpc"

  tags = {
    Name = "kredar-eip"
  }
}
