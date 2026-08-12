variable "gcp_project" {
  type        = string
  description = "GCP project id."
}
variable "gcp_region" {
  type        = string
  default     = "europe-west1"
  description = "GCP region."
}
variable "gcp_zone" {
  type        = string
  default     = "europe-west1-b"
  description = "GCP zone."
}
variable "gcp_credentials" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Service-account JSON key contents. Leave empty to use Application Default Credentials (gcloud auth)."
}

variable "hosts" {
  type        = set(string)
  default     = ["shared"]
  description = "Host keys to create. Default single \"shared\" box; use [\"staging\",\"production\"] for one per env."
}

variable "machine_type" {
  type        = string
  default     = "e2-standard-2"
  description = "GCE machine type (e2-standard-2 = 2 vCPU / 8 GB)."
}

variable "image" {
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
  description = "Boot image family/path."
}

variable "boot_disk_gb" {
  type        = number
  default     = 40
  description = "Boot disk size in GB."
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
