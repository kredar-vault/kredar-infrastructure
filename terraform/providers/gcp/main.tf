# GCP Compute Engine host(s). Same contract as the other provider roots: an
# Ubuntu 24.04 box prepared by the shared cloud-init (delivered as the GCE
# startup-script), outputting a public IP + ssh user.

locals {
  startup = { for h in var.hosts : h => templatefile("${path.module}/../../shared/bootstrap.sh.tftpl", {
    deploy_user         = var.deploy_user
    ssh_public_key      = var.ssh_public_key
    create_edge_network = true
  }) }
}

resource "google_compute_firewall" "web" {
  name    = "kredar-web"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["kredar-web"]
}

resource "google_compute_instance" "host" {
  for_each = var.hosts

  name         = "kredar-${each.key}"
  machine_type = var.machine_type
  zone         = var.gcp_zone
  tags         = ["kredar-web"]

  boot_disk {
    initialize_params {
      image = var.image
      size  = var.boot_disk_gb
      type  = "pd-ssd"
    }
  }

  network_interface {
    network = "default"
    access_config {} # ephemeral public IP; promote to a static address before DNS if desired
  }

  metadata = {
    enable-oslogin = "FALSE" # use the metadata SSH key below, not OS Login
    ssh-keys       = "${var.deploy_user}:${var.ssh_public_key}"
  }

  metadata_startup_script = local.startup[each.key]

  labels = {
    project     = "kredar"
    environment = each.key
  }
}
