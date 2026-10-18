output "container_name" {
  value = docker_container.postgres.name
}

output "internal_host" {
  description = "Hostname reachable from other containers on the same network."
  value       = "postgres"
}

output "host_endpoint" {
  value = "${var.bind_address}:${var.port}"
}

output "databases" {
  value = nonsensitive(keys(var.databases))
}

output "volume_name" {
  value = docker_volume.data.name
}
