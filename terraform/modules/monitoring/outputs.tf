output "prometheus_url" {
  value = "http://${var.bind_address}:${var.prometheus_port}"
}

output "grafana_url" {
  value = "http://${var.bind_address}:${var.grafana_port}"
}

output "statsd_host" {
  description = "StatsD exporter hostname on the data network."
  value       = docker_container.statsd_exporter.hostname
}
