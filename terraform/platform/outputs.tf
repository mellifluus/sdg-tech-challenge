output "networks" {
  description = "Docker networks created by the stack."
  value = {
    data       = local.foundation.networks.data
    monitoring = local.foundation.networks.monitoring
  }
}

output "minio" {
  description = "MinIO endpoints."
  value = {
    api_url           = module.minio.api_url
    console_url       = module.minio.console_url
    internal_endpoint = module.minio.internal_endpoint
    root_user         = local.foundation.minio_root_user
    app_user          = var.minio_app_user
    buckets           = module.minio.buckets
  }
}

output "minio_root_password" {
  description = "MinIO root password (terraform output -raw minio_root_password)."
  value       = local.foundation.minio_root_password
  sensitive   = true
}

output "minio_app_password" {
  description = "Secret key of the least-privilege pipeline user."
  value       = local.foundation.minio_app_password
  sensitive   = true
}

output "postgres" {
  description = "PostgreSQL connection info (passwords: terraform output postgres_passwords)."
  value = {
    container_name    = module.postgres.container_name
    host_endpoint     = module.postgres.host_endpoint
    internal_host     = module.postgres.internal_host
    databases         = module.postgres.databases
    orchestrator_db   = var.orchestrator_db_name
    warehouse_db      = var.warehouse_db_name
    orchestrator_conn = "postgresql://${var.orchestrator_db_name}:<password>@${module.postgres.internal_host}:5432/${var.orchestrator_db_name}"
  }
}

output "postgres_passwords" {
  description = "Generated PostgreSQL passwords (terraform output -json postgres_passwords)."
  value = {
    postgres                   = local.foundation.postgres_passwords.superuser
    (var.orchestrator_db_name) = local.foundation.postgres_passwords.orchestrator
    (var.warehouse_db_name)    = local.foundation.postgres_passwords.warehouse
  }
  sensitive = true
}

output "volumes" {
  description = "Persistent volumes (owned by the foundation layer)."
  value       = local.foundation.volumes
}

output "mc_image" {
  description = "MinIO client image."
  value       = var.minio_mc_image
}

output "postgres_image" {
  description = "PostgreSQL image (also provides psql / pg_isready)."
  value       = var.postgres_image
}

output "monitoring" {
  description = "Monitoring endpoints."
  value = {
    prometheus_url = module.monitoring.prometheus_url
    grafana_url    = module.monitoring.grafana_url
    grafana_user   = var.grafana_admin_user
  }
}

output "grafana_admin_password" {
  value     = local.foundation.grafana_admin_password
  sensitive = true
}

output "airflow" {
  description = "Airflow endpoint and connection ids."
  value = {
    url            = module.airflow.url
    admin_user     = module.airflow.admin_user
    image          = module.airflow.image
    connection_ids = module.airflow.connection_ids
  }
}

output "airflow_admin_password" {
  value     = local.foundation.airflow_admin_password
  sensitive = true
}
