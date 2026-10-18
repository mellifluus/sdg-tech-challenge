output "container_name" {
  value = docker_container.minio.name
}

output "internal_endpoint" {
  description = "Endpoint reachable by other containers on the same network."
  value       = "http://minio:9000"
}

output "api_url" {
  value = "http://${var.bind_address}:${var.api_port}"
}

output "console_url" {
  value = "http://${var.bind_address}:${var.console_port}"
}

output "volume_name" {
  value = docker_volume.data.name
}

output "buckets" {
  value = var.buckets
}

output "bootstrap_exit_code" {
  description = "Exit code of the bootstrap job."
  value       = docker_container.bootstrap.exit_code
}
