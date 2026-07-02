variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "ami_id" {
  description = "Ubuntu 24.04 LTS AMI ID (varies by region - check AWS console)"
  type        = string
}

variable "public_key_path" {
  description = "Path to the deploy SSH public key file"
  type        = string
  default     = "~/.ssh/kredar_deploy.pub"
}

variable "ssh_ingress_cidr" {
  description = "CIDR allowed to SSH in. Narrow this to a known network for hardening."
  type        = string
  default     = "0.0.0.0/0"
}

variable "root_volume_gb" {
  description = "Root EBS volume size (GiB)"
  type        = number
  default     = 20
}
