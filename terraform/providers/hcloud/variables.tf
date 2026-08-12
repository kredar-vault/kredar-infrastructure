variable "hcloud_token" {
  type        = string
  sensitive   = true
  description = "Hetzner Cloud API token (Project -> Security -> API tokens, read+write)."
}

variable "hosts" {
  type        = set(string)
  default     = ["shared"]
  description = "Host keys to create. Default single \"shared\" box; use [\"staging\",\"production\"] for one per env."
}

variable "server_type" {
  type        = string
  default     = "cx22"
  description = <<-EOT
    Hetzner server type. Default cx22 is the smallest current-gen x86 box
    (2 vCPU / 4 GB / 40 GB) to keep spend low. Must be an x86 type — the app
    images are amd64, so ARM (cax*) types will not run them. Size up (cx32/cx42)
    if one box hosting every product + environment runs short on RAM.
  EOT
}

variable "location" {
  type        = string
  default     = "nbg1"
  description = "Hetzner location (nbg1, fsn1, hel1, ash, hil, ...)."
}

variable "image" {
  type        = string
  default     = "ubuntu-24.04"
  description = "Base image."
}

variable "deploy_user" {
  type        = string
  default     = "deploy"
  description = "Login user created on the host (key-only, docker + sudo). Set as SSH_USER in the GitHub Environments."
}

variable "ssh_public_key" {
  type        = string
  description = "Public SSH key authorised on the host. Private key -> SSH_PRIVATE_KEY GitHub secret."
}
