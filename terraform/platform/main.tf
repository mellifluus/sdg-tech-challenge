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

  monitoring_network = local.foundation.networks.monitoring
}

module "postgres" {
  source = "../modules/postgres"

  name_prefix         = local.foundation.project_name
  image               = var.postgres_image
  network_name        = local.foundation.networks.data
  volume_name         = local.foundation.volumes.postgres
  bind_address        = var.bind_address
  port                = var.postgres_port
  superuser_password  = local.foundation.postgres_passwords.superuser
  monitoring_password = local.foundation.postgres_passwords.monitoring
  labels              = local.common_labels

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

module "monitoring" {
  source = "../modules/monitoring"

  name_prefix        = local.foundation.project_name
  monitoring_network = local.foundation.networks.monitoring
  data_network       = local.foundation.networks.data
  bind_address       = var.bind_address
  labels             = local.common_labels

  prometheus_image     = var.prometheus_image
  prometheus_port      = var.prometheus_port
  prometheus_volume    = local.foundation.volumes.prometheus
  prometheus_retention = var.prometheus_retention

  postgres_exporter_image      = var.postgres_exporter_image
  postgres_host                = module.postgres.internal_address
  postgres_monitoring_password = local.foundation.postgres_passwords.monitoring
  minio_target                 = module.minio.internal_address

  depends_on = [module.postgres, module.minio]
}
