# Long-lived layer: everything that must survive a platform teardown.

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

# STORAGE

resource "docker_volume" "data" {
  for_each = toset(["minio", "postgres", "prometheus", "grafana", "airflow-logs"])

  name = "${var.project_name}-${each.key}-data"

  dynamic "labels" {
    for_each = local.common_labels
    content {
      label = labels.key
      value = labels.value
    }
  }
}
