# Used by the platform layer through terraform_remote_state.

output "project_name" {
  description = "Prefix used for every Docker object."
  value       = var.project_name
}

output "networks" {
  description = "Docker networks."
  value = {
    data       = docker_network.data.name
    monitoring = docker_network.monitoring.name
  }
}

output "volumes" {
  description = "Persistent Docker volumes, keyed by service."
  value       = { for k, v in docker_volume.data : k => v.name }
}

output "minio_root_user" {
  description = "MinIO root user."
  value       = var.minio_root_user
}

output "minio_root_password" {
  description = "MinIO root password."
  value       = local.minio_root_password
  sensitive   = true
}

output "minio_app_password" {
  description = "Secret key of the least-privilege MinIO user."
  value       = random_password.minio_app.result
  sensitive   = true
}

output "postgres_passwords" {
  description = "PostgreSQL passwords, keyed by role function (superuser, orchestrator, warehouse, monitoring)."
  value       = { for k, v in random_password.postgres : k => v.result }
  sensitive   = true
}
