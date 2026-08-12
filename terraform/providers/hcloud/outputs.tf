output "host_public_ips" {
  description = "Public IPv4 per host key. Set as SSH_HOST in the matching GitHub Environment(s) and point DNS A records here."
  value       = { for k, s in hcloud_server.host : k => s.ipv4_address }
}

output "ssh_user" {
  description = "Login user for the host(s). Set as SSH_USER in each GitHub Environment."
  value       = var.deploy_user
}
