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

locals {
  environments = toset(["staging", "production"])
}

# Security group — one per environment (HTTP/HTTPS/SSH; app port 8080 stays
# private to the compose network and is intentionally NOT opened publicly).
resource "aws_security_group" "kredar" {
  for_each    = local.environments
  name        = "kredar-${each.key}-sg"
  description = "Kredar ${each.key}: allow HTTP, HTTPS, SSH"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_ingress_cidr]
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "kredar-${each.key}-sg"
    Project = "kredar"
    Env     = each.key
  }
}

# Shared deploy key pair (the private half lives only in GitHub secrets).
resource "aws_key_pair" "kredar" {
  key_name   = "kredar-deploy-key"
  public_key = file(pathexpand(var.public_key_path))
}

# One EC2 host per environment. Docker is installed on first boot via cloud-init.
resource "aws_instance" "kredar" {
  for_each               = local.environments
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.kredar.key_name
  vpc_security_group_ids = [aws_security_group.kredar[each.key].id]

  user_data = <<-EOF
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get install -y ca-certificates curl git rsync
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    systemctl enable --now docker
    usermod -aG docker ubuntu
    mkdir -p /opt/kredar-infrastructure
    chown -R ubuntu:ubuntu /opt/kredar-infrastructure
    # Avoid jumbo-frame (MTU 9001) PMTU blackholes to external TLS (Let's Encrypt).
    IFACE=$(ip route | awk '/default/{print $5; exit}')
    ip link set dev "$IFACE" mtu 1500 || true
    printf '[Unit]\nAfter=network-online.target\nWants=network-online.target\n[Service]\nType=oneshot\nExecStart=/usr/sbin/ip link set dev %s mtu 1500\nRemainAfterExit=yes\n[Install]\nWantedBy=multi-user.target\n' "$IFACE" > /etc/systemd/system/set-mtu.service
    systemctl enable set-mtu.service || true
  EOF

  root_block_device {
    volume_size = var.root_volume_gb
    volume_type = "gp3"
  }

  tags = {
    Name    = "kredar-${each.key}"
    Project = "kredar"
    Env     = each.key
  }
}

# Static Elastic IP per host (use these for DNS A records).
resource "aws_eip" "kredar" {
  for_each = local.environments
  instance = aws_instance.kredar[each.key].id
  domain   = "vpc"

  tags = {
    Name    = "kredar-${each.key}-eip"
    Project = "kredar"
    Env     = each.key
  }
}
