resource "docker_image" "postgres" {
  name         = var.image
  keep_locally = true
}

resource "docker_container" "postgres" {
  name     = "${var.name_prefix}-postgres"
  image    = docker_image.postgres.image_id
  hostname = "postgres"
  restart  = "unless-stopped"

  env = [
    "POSTGRES_PASSWORD=${var.superuser_password}",
    "PGDATA=/var/lib/postgresql/data/pgdata",
  ]

  command = [
    "postgres",
    "-c", "shared_preload_libraries=pg_stat_statements",
    "-c", "log_min_duration_statement=1000",
    "-c", "password_encryption=scram-sha-256",
  ]

  ports {
    internal = 5432
    external = var.port
    ip       = var.bind_address
  }

  volumes {
    volume_name    = var.volume_name
    container_path = "/var/lib/postgresql/data"
  }

  networks_advanced {
    name    = var.network_name
    aliases = ["postgres"]
  }

  healthcheck {
    test         = ["CMD-SHELL", "pg_isready -U postgres -d postgres -h 127.0.0.1"]
    interval     = "5s"
    timeout      = "3s"
    retries      = 10
    start_period = "10s"
  }

  # Block the apply until the healthcheck is green, so the bootstrap job
  # (and anything depending on this module) starts against a ready server.
  wait         = true
  wait_timeout = 120

  dynamic "labels" {
    for_each = var.labels
    content {
      label = labels.key
      value = labels.value
    }
  }
}
