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
