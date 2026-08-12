# Hetzner Cloud host(s). Same contract as the other provider roots: an
# Ubuntu 24.04 box prepared by the shared cloud-init, outputting a public IP +
# ssh user for the GitHub Environments and DNS.

locals {
  user_data = { for h in var.hosts : h => templatefile("${path.module}/../../shared/bootstrap.sh.tftpl", {
    deploy_user         = var.deploy_user
    ssh_public_key      = var.ssh_public_key
    create_edge_network = true
  }) }
}

# Public HTTP/HTTPS + key-only SSH. GitHub-hosted runners use dynamic IPs, so
# 22 is open with key-only auth (matches the AWS root's posture).
resource "hcloud_firewall" "web" {
  name = "kredar-web"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_server" "host" {
  for_each = var.hosts

  name         = "kredar-${each.key}"
  server_type  = var.server_type
  location     = var.location
  image        = var.image
  user_data    = local.user_data[each.key]
  firewall_ids = [hcloud_firewall.web.id]

  labels = {
    project     = "kredar"
    environment = each.key
  }
}
