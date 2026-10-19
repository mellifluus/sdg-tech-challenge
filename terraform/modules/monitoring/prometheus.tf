resource "docker_image" "prometheus" {
  name         = var.prometheus_image
  keep_locally = true
}

locals {
  prometheus_config = templatefile("${path.module}/prometheus.yml.tftpl", {
    project         = var.name_prefix
    scrape_interval = var.scrape_interval
    minio_target    = var.minio_target
  })
}

resource "docker_container" "prometheus" {
  name     = "${var.name_prefix}-prometheus"
  image    = docker_image.prometheus.image_id
  hostname = "prometheus"
  restart  = "unless-stopped"

  command = [
    "--config.file=/etc/prometheus/prometheus.yml",
    "--storage.tsdb.path=/prometheus",
    "--storage.tsdb.retention.time=${var.prometheus_retention}",
  ]

  upload {
    file    = "/etc/prometheus/prometheus.yml"
    content = local.prometheus_config
  }

  ports {
    internal = 9090
    external = var.prometheus_port
    ip       = var.bind_address
  }

  volumes {
    volume_name    = var.prometheus_volume
    container_path = "/prometheus"
  }

  # Monitoring network only: MinIO joins it for scraping, PostgreSQL is reached via the exporter.
  networks_advanced {
    name    = var.monitoring_network
    aliases = ["prometheus"]
  }

  healthcheck {
    test     = ["CMD", "wget", "-q", "--spider", "http://localhost:9090/-/ready"]
    interval = "10s"
    timeout  = "3s"
    retries  = 6
  }

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
