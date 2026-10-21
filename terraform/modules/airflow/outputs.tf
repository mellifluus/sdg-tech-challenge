output "url" {
  value = "http://${var.bind_address}:${var.port}"
}

output "admin_user" {
  value = var.admin_user
}

output "image" {
  description = "Locally built Airflow image."
  value       = docker_image.airflow.name
}

output "connection_ids" {
  description = "Airflow connection ids injected from Terraform."
  value = {
    minio     = var.minio_conn_id
    warehouse = var.warehouse_conn_id
  }
}
