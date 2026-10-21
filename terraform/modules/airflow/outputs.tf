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
