variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "Ubuntu 24.04 LTS AMI ID (varies by region - check AWS console)"
  type        = string
}

variable "public_key_path" {
  description = "Path to your local SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}
