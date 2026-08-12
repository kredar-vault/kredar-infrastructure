output "host_public_ips" {
  description = "Public IP per host key. Set as SSH_HOST in the matching GitHub Environment(s) and point DNS A records here."
  value       = { for k, i in google_compute_instance.host : k => i.network_interface[0].access_config[0].nat_ip }
}

output "ssh_user" {
  description = "Login user for the host(s). Set as SSH_USER in each GitHub Environment."
  value       = var.deploy_user
}
