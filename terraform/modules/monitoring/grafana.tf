resource "docker_image" "grafana" {
  name         = var.grafana_image
  keep_locally = true
}

locals {
  grafana_datasources = templatefile("${path.module}/grafana-datasources.yml.tftpl", {
    prometheus_url  = "http://prometheus:9090"
    scrape_interval = var.scrape_interval
  })

  # Every JSON file in grafana/dashboards is provisioned automatically.
  grafana_dashboards = fileset("${path.module}/grafana/dashboards", "*.json")
}

resource "docker_container" "grafana" {
  name     = "${var.name_prefix}-grafana"
  image    = docker_image.grafana.image_id
  hostname = "grafana"
  restart  = "unless-stopped"

  env = [
    "GF_SECURITY_ADMIN_USER=${var.grafana_admin_user}",
    "GF_SECURITY_ADMIN_PASSWORD=${var.grafana_admin_password}",
    "GF_USERS_ALLOW_SIGN_UP=false",
    "GF_AUTH_ANONYMOUS_ENABLED=false",
    "GF_ANALYTICS_REPORTING_ENABLED=false",
    "GF_ANALYTICS_CHECK_FOR_UPDATES=false",
    "GF_NEWS_NEWS_FEED_ENABLED=false",
    "GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH=/etc/grafana/dashboards/platform-overview.json",
  ]

  upload {
    file    = "/etc/grafana/provisioning/datasources/datasources.yml"
    content = local.grafana_datasources
  }

  upload {
    file    = "/etc/grafana/provisioning/dashboards/dashboards.yml"
    content = file("${path.module}/grafana/grafana-dashboards.yml")
  }

  dynamic "upload" {
    for_each = local.grafana_dashboards
    content {
      file    = "/etc/grafana/dashboards/${upload.value}"
      content = file("${path.module}/grafana/dashboards/${upload.value}")
    }
  }

  upload {
    file    = "/etc/grafana/provisioning/alerting/alerts.yml"
    content = file("${path.module}/grafana/grafana-alerts.yml")
  }

  ports {
    internal = 3000
    external = var.grafana_port
    ip       = var.bind_address
  }

  volumes {
    volume_name    = var.grafana_volume
    container_path = "/var/lib/grafana"
  }

  networks_advanced {
    name    = var.monitoring_network
    aliases = ["grafana"]
  }

  healthcheck {
    test     = ["CMD", "wget", "-q", "--spider", "http://localhost:3000/api/health"]
    interval = "10s"
    timeout  = "3s"
    retries  = 10
  }

  wait         = true
  wait_timeout = 180

  dynamic "labels" {
    for_each = var.labels
    content {
      label = labels.key
      value = labels.value
    }
  }

  depends_on = [docker_container.prometheus]
}
