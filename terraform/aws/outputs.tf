output "public_ip" {
  value = aws_instance.app.public_ip
}

output "app_url" {
  description = "Where the app is reachable once deployed"
  value       = "http://${aws_instance.app.public_ip}:${var.app_port}"
}

output "ssh_command" {
  value = "ssh ubuntu@${aws_instance.app.public_ip}"
}
