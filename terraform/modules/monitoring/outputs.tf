output "prometheus_url" {
  value = "http://${var.bind_address}:${var.prometheus_port}"
}

output "grafana_url" {
  value = "http://${var.bind_address}:${var.grafana_port}"
}
