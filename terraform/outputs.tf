output "host_public_ips" {
  description = "Static Elastic IPs per environment — use these for DNS A records + GitHub SSH_HOST."
  value       = { for env, eip in aws_eip.kredar : env => eip.public_ip }
}

output "ssh_commands" {
  description = "SSH into each host with the deploy key."
  value       = { for env, eip in aws_eip.kredar : env => "ssh -i ~/.ssh/kredar_deploy ubuntu@${eip.public_ip}" }
}
