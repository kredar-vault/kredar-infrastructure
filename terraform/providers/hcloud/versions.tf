terraform {
  required_version = ">= 1.6"
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.48"
    }
  }
  # backend "s3" { ... }  # own state; never touches the AWS root's state.
}

provider "hcloud" {
  token = var.hcloud_token
}
