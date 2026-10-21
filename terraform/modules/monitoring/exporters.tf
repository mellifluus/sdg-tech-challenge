resource "docker_image" "postgres_exporter" {
  name         = var.postgres_exporter_image
  keep_locally = true
}

resource "docker_container" "postgres_exporter" {
  name     = "${var.name_prefix}-postgres-exporter"
  image    = docker_image.postgres_exporter.image_id
  hostname = "postgres-exporter"
  restart  = "unless-stopped"

  # pg_stat_statements is preloaded by the postgres module and created by its bootstrap.
  command = ["--collector.stat_statements"]

  env = [
    "DATA_SOURCE_URI=${var.postgres_host}/postgres?sslmode=disable",
    "DATA_SOURCE_USER=monitoring",
    "DATA_SOURCE_PASS=${var.postgres_monitoring_password}",
  ]

  networks_advanced {
    name = var.data_network
  }

  networks_advanced {
    name    = var.monitoring_network
    aliases = ["postgres-exporter"]
  }

  healthcheck {
    test     = ["CMD", "wget", "-q", "--spider", "http://localhost:9187/metrics"]
    interval = "15s"
    timeout  = "5s"
    retries  = 5
  }

  dynamic "labels" {
    for_each = var.labels
    content {
      label = labels.key
      value = labels.value
    }
  }
}

resource "docker_image" "statsd_exporter" {
  name         = var.statsd_exporter_image
  keep_locally = true
}

resource "docker_container" "statsd_exporter" {
  name     = "${var.name_prefix}-statsd-exporter"
  image    = docker_image.statsd_exporter.image_id
  hostname = "statsd-exporter"
  restart  = "unless-stopped"
  command  = ["--statsd.mapping-config=/etc/statsd-exporter/mapping.yml"]

  upload {
    file    = "/etc/statsd-exporter/mapping.yml"
    content = file("${path.module}/statsd-mapping.yml")
  }

  networks_advanced {
    name    = var.data_network
    aliases = ["statsd-exporter"]
  }

  networks_advanced {
    name    = var.monitoring_network
    aliases = ["statsd-exporter"]
  }

  healthcheck {
    test     = ["CMD", "wget", "-q", "--spider", "http://localhost:9102/metrics"]
    interval = "15s"
    timeout  = "5s"
    retries  = 5
  }

  dynamic "labels" {
    for_each = var.labels
    content {
      label = labels.key
      value = labels.value
    }
  }
}
