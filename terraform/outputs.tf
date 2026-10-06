output "app_url" {
  description = "Where the running app is reachable"
  value       = "http://localhost:${var.host_port}"
}

output "container_name" {
  value = docker_container.app.name
}
