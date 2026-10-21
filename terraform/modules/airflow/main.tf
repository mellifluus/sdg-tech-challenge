resource "docker_image" "airflow" {
  name         = "${var.name_prefix}-airflow:local"
  keep_locally = true
  build {
    context    = path.module
    build_args = { AIRFLOW_IMAGE = var.base_image }
  }
  triggers = {
    base_image = var.base_image
    dockerfile = filesha1("${path.module}/Dockerfile")
  }
}

locals {
  api_host = "airflow-api-server"

  env = [
    "AIRFLOW__CORE__EXECUTOR=LocalExecutor",
    "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=postgresql+psycopg2://${var.metadata_db}:${var.metadata_password}@${var.postgres_host}:5432/${var.metadata_db}",
    "AIRFLOW__CORE__FERNET_KEY=${var.fernet_key}",
    "AIRFLOW__API_AUTH__JWT_SECRET=${var.jwt_secret}",
    "AIRFLOW__CORE__EXECUTION_API_SERVER_URL=http://${local.api_host}:8080/execution/",
    "AIRFLOW__CORE__LOAD_EXAMPLES=False",
    "AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION=False",
    "AIRFLOW__DAG_PROCESSOR__REFRESH_INTERVAL=30",
    "AIRFLOW__CORE__SIMPLE_AUTH_MANAGER_USERS=${var.admin_user}:admin",
    "AIRFLOW__CORE__SIMPLE_AUTH_MANAGER_PASSWORDS_FILE=/opt/airflow/passwords/passwords.json",
    "AIRFLOW__SCHEDULER__ENABLE_HEALTH_CHECK=True",
  ]

  services = {
    api-server = {
      healthcheck = ["CMD", "curl", "-fsS", "http://localhost:8080/api/v2/monitor/health"]
      ports       = [{ internal = 8080, external = var.port }]
    }
    scheduler = {
      healthcheck = ["CMD", "curl", "-fsS", "http://localhost:8974/health"]
      ports       = []
    }
    dag-processor = {
      healthcheck = ["CMD-SHELL", "airflow jobs check --job-type DagProcessorJob --local"]
      ports       = []
    }
  }
}

# One-shot job to create the database schema and run migrations.
resource "docker_container" "init" {
  name     = "${var.name_prefix}-airflow-init"
  image    = docker_image.airflow.image_id
  must_run = false
  attach   = true
  logs     = true
  command  = ["db", "migrate"]
  env      = local.env

  networks_advanced {
    name = var.network_name
  }

  dynamic "labels" {
    for_each = var.labels
    content {
      label = labels.key
      value = labels.value
    }
  }

  timeouts {
    create = "5m"
  }

  lifecycle {
    postcondition {
      condition     = self.exit_code == 0
      error_message = "Airflow db migrate failed (exit code ${coalesce(self.exit_code, -1)}). Check: docker logs ${self.name}"
    }
  }
}

resource "docker_container" "airflow" {
  for_each = local.services

  name     = "${var.name_prefix}-airflow-${each.key}"
  image    = docker_image.airflow.image_id
  hostname = "airflow-${each.key}"
  restart  = "unless-stopped"
  command  = [each.key]
  env      = local.env

  upload {
    file    = "/opt/airflow/passwords/passwords.json"
    content = jsonencode({ (var.admin_user) = var.admin_password })
    # needs read/write permissions for airflow user (50000) to read the file, otherwise the webserver will fail to start
    owner       = "50000"
    group       = "0"
    permissions = "0600"
  }

  dynamic "ports" {
    for_each = each.value.ports
    content {
      internal = ports.value.internal
      external = ports.value.external
      ip       = var.bind_address
    }
  }

  volumes {
    volume_name    = var.logs_volume
    container_path = "/opt/airflow/logs"
  }

  networks_advanced {
    name    = var.network_name
    aliases = ["airflow-${each.key}"]
  }

  healthcheck {
    test         = each.value.healthcheck
    interval     = "15s"
    timeout      = "10s"
    retries      = 10
    start_period = "30s"
  }

  wait         = true
  wait_timeout = 300

  dynamic "labels" {
    for_each = var.labels
    content {
      label = labels.key
      value = labels.value
    }
  }

  depends_on = [docker_container.init]
}
