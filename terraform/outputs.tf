output "networks" {
  description = "Docker networks created by the stack."
  value = {
    data = docker_network.data.name
  }
}

output "minio" {
  description = "MinIO endpoints."
  value = {
    api_url           = module.minio.api_url
    console_url       = module.minio.console_url
    internal_endpoint = module.minio.internal_endpoint
    root_user         = var.minio_root_user
    app_user          = var.minio_app_user
    buckets           = module.minio.buckets
  }
}

output "minio_root_password" {
  description = "MinIO root password (terraform output -raw minio_root_password)."
  value       = local.minio_root_password
  sensitive   = true
}

output "minio_app_password" {
  description = "Secret key of the least-privilege pipeline user."
  value       = random_password.minio_app.result
  sensitive   = true
}

output "postgres" {
  description = "PostgreSQL connection info (passwords: terraform output postgres_passwords)."
  value = {
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
    postgres                   = random_password.postgres["superuser"].result
    (var.orchestrator_db_name) = random_password.postgres["orchestrator"].result
    (var.warehouse_db_name)    = random_password.postgres["warehouse"].result
  }
  sensitive = true
}
