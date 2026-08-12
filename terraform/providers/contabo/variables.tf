# --- Contabo API credentials (from the Contabo customer control panel) ------
variable "contabo_client_id" {
  type        = string
  description = "Contabo OAuth2 client id."
}
variable "contabo_client_secret" {
  type        = string
  sensitive   = true
  description = "Contabo OAuth2 client secret."
}
variable "contabo_api_user" {
  type        = string
  description = "Contabo API user (your Contabo account email)."
}
variable "contabo_api_password" {
  type        = string
  sensitive   = true
  description = "Contabo API password (generated in the control panel)."
}

# --- Host shape --------------------------------------------------------------
variable "hosts" {
  type        = set(string)
  default     = ["shared"]
  description = <<-EOT
    Host keys to create. Default is a single "shared" box that runs every
    product/environment behind one Traefik (the cost-consolidation topology).
    Use e.g. ["staging","production"] for one box per environment instead.
  EOT
}

variable "product_id" {
  type        = string
  default     = "V45"
  description = <<-EOT
    Contabo product id (VPS tier). Default V45 targets the smallest "Cloud VPS 10"
    tier to keep spend low. Contabo periodically revises these ids — confirm the
    current smallest id in the control panel / API before apply. Size up if one box
    hosting every product + environment runs short on RAM.
  EOT
}

variable "region" {
  type        = string
  default     = "EU"
  description = "Contabo region code (EU, US-central, US-east, US-west, SIN, ...)."
}

variable "image_id" {
  type        = string
  description = "Contabo image id for Ubuntu 24.04 (look up via `data.contabo_image` or the API)."
}

variable "deploy_user" {
  type        = string
  default     = "deploy"
  description = "Login user created on the host (key-only, docker + sudo). Set as SSH_USER in the GitHub Environments."
}

variable "ssh_public_key" {
  type        = string
  description = "Public SSH key authorised on the host. The matching private key becomes the SSH_PRIVATE_KEY GitHub secret."
}
