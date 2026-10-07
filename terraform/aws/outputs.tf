output "public_ip" {
  value = aws_eip.app.public_ip
}

output "private_ip" {
  description = "In-VPC address, used by Jenkins (deploy) and Prometheus (scrape)"
  value       = aws_instance.app.private_ip
}

output "app_url" {
  description = "Where the app is reachable once deployed"
  value       = "http://${aws_eip.app.public_ip}:${var.app_port}"
}

output "ssh_command" {
  value = "ssh ubuntu@${aws_eip.app.public_ip}"
}
