output "prometheus_url" {
  value = "http://${var.bind_address}:${var.prometheus_port}"
}
