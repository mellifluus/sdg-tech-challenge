# NETWORKING

resource "docker_network" "data" {
  name   = "${var.project_name}-data"
  driver = "bridge"

  dynamic "labels" {
    for_each = local.common_labels
    content {
      label = labels.key
      value = labels.value
    }
  }
}

resource "docker_network" "monitoring" {
  name   = "${var.project_name}-monitoring"
  driver = "bridge"

  dynamic "labels" {
    for_each = local.common_labels
    content {
      label = labels.key
      value = labels.value
    }
  }
}

# OBJECT STORAGE

module "minio" {
  source = "./modules/minio"

  name_prefix   = var.project_name
  image         = var.minio_image
  network_name  = docker_network.data.name
  root_user     = var.minio_root_user
  root_password = local.minio_root_password
  bind_address  = var.bind_address
  api_port      = var.minio_api_port
  console_port  = var.minio_console_port
  labels        = local.common_labels
  mc_image      = var.minio_mc_image
  buckets       = var.minio_buckets
  app_user      = var.minio_app_user
  app_password  = random_password.minio_app.result
}
