# OBJECT STORAGE

module "minio" {
  source = "../modules/minio"

  name_prefix   = local.foundation.project_name
  image         = var.minio_image
  network_name  = local.foundation.networks.data
  volume_name   = local.foundation.volumes.minio
  root_user     = local.foundation.minio_root_user
  root_password = local.foundation.minio_root_password
  bind_address  = var.bind_address
  api_port      = var.minio_api_port
  console_port  = var.minio_console_port
  labels        = local.common_labels
  mc_image      = var.minio_mc_image
  buckets       = var.minio_buckets
  app_user      = var.minio_app_user
  app_password  = local.foundation.minio_app_password
}

# DB

module "postgres" {
  source = "../modules/postgres"

  name_prefix        = local.foundation.project_name
  image              = var.postgres_image
  network_name       = local.foundation.networks.data
  volume_name        = local.foundation.volumes.postgres
  bind_address       = var.bind_address
  port               = var.postgres_port
  superuser_password = local.foundation.postgres_passwords.superuser
  labels             = local.common_labels

  databases = {
    (var.orchestrator_db_name) = {
      description = "orchestrator metadata"
      password    = local.foundation.postgres_passwords.orchestrator
    }
    (var.warehouse_db_name) = {
      description = "destination warehouse"
      password    = local.foundation.postgres_passwords.warehouse
    }
  }
}
