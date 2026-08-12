terraform {
  required_version = ">= 1.6"
  required_providers {
    contabo = {
      source  = "contabo/contabo"
      version = "~> 0.1.28"
    }
  }

  # Recommended: a remote backend so the state isn't only on your laptop.
  # This root owns ONLY the Contabo host(s); the AWS root (../../) keeps its own
  # separate state, so applying here never touches the live AWS resources.
  # backend "s3" { ... }
}

provider "contabo" {
  oauth2_client_id     = var.contabo_client_id
  oauth2_client_secret = var.contabo_client_secret
  oauth2_user          = var.contabo_api_user
  oauth2_pass          = var.contabo_api_password
}
