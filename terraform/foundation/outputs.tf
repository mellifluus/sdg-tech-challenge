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

output "grafana_admin_password" {
  description = "Grafana admin password."
  value       = random_password.grafana_admin.result
  sensitive   = true
}

output "airflow_admin_password" {
  description = "Airflow admin password."
  value       = random_password.airflow_admin.result
  sensitive   = true
}

output "airflow_secrets" {
  description = "Airflow internal secrets (fernet key, JWT signing secret)."
  value = {
    fernet_key = local.airflow_fernet_key
    jwt_secret = random_password.airflow_jwt.result
  }
  sensitive = true
}
