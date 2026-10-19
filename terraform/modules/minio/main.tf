resource "docker_image" "minio" {
  name         = var.image
  keep_locally = true
}

resource "docker_container" "minio" {
  name     = "${var.name_prefix}-minio"
  image    = docker_image.minio.image_id
  hostname = "minio"
  restart  = "unless-stopped"

  command = ["server", "/data", "--address", ":9000", "--console-address", ":9001"]

  env = [
    "MINIO_ROOT_USER=${var.root_user}",
    "MINIO_ROOT_PASSWORD=${var.root_password}",
    "MINIO_PROMETHEUS_AUTH_TYPE=public",
  ]

  ports {
    internal = 9000
    external = var.api_port
    ip       = var.bind_address
  }

  ports {
    internal = 9001
    external = var.console_port
    ip       = var.bind_address
  }

  volumes {
    volume_name    = var.volume_name
    container_path = "/data"
  }

  networks_advanced {
    name    = var.network_name
    aliases = ["minio"]
  }

  # Optional second network so Prometheus can scrape metrics without joining the data network.
  dynamic "networks_advanced" {
    for_each = var.monitoring_network == null ? [] : [var.monitoring_network]
    content {
      name    = networks_advanced.value
      aliases = ["minio"]
    }
  }

  dynamic "labels" {
    for_each = var.labels
    content {
      label = labels.key
      value = labels.value
    }
  }
}
