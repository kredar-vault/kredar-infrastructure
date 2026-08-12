# Contabo host(s) for the cost-consolidated topology: by default a single
# "shared" VPS that runs every product/environment behind one Traefik.
#
# The host is prepared entirely by cloud-init (../../shared/bootstrap.sh.tftpl):
# Docker + compose, a key-only `deploy_user`, fail2ban, and the external `edge`
# network the shared-Traefik stack needs. Nothing product-specific is baked into
# the image — the GitHub Actions deploy workflow ships the stacks over SSH.

locals {
  user_data = { for h in var.hosts : h => templatefile("${path.module}/../../shared/bootstrap.sh.tftpl", {
    deploy_user         = var.deploy_user
    ssh_public_key      = var.ssh_public_key
    create_edge_network = true
  }) }
}

resource "contabo_instance" "host" {
  for_each = var.hosts

  display_name = "kredar-${each.key}"
  product_id   = var.product_id
  region       = var.region
  image_id     = var.image_id
  user_data    = local.user_data[each.key]
}
