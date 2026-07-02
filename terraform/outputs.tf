output "instance_public_ip" {
  description = "EC2 instance public IP (may change on restart)"
  value       = aws_instance.kredar_server.public_ip
}

output "elastic_ip" {
  description = "Static Elastic IP — use this for DNS and frontend config"
  value       = aws_eip.kredar_eip.public_ip
}

output "ssh_command" {
  description = "SSH into the server"
  value       = "ssh ubuntu@${aws_eip.kredar_eip.public_ip}"
}
