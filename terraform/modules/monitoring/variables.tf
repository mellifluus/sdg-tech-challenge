variable "name_prefix" {
  description = "Prefix for container names."
  type        = string
}

variable "monitoring_network" {
  description = "Network used by the monitoring components."
  type        = string
}

variable "data_network" {
  description = "Application network the PostgreSQL exporter joins to reach the database."
  type        = string
}

variable "bind_address" {
  description = "Host IP the ports bind to."
  type        = string
}

variable "labels" {
  description = "Labels applied to every Docker object."
  type        = map(string)
  default     = {}
}

variable "prometheus_image" {
  description = "Docker image for Prometheus."
  type        = string
}

variable "prometheus_port" {
  description = "Port Prometheus binds to."
  type        = number
  default     = 9090
}

variable "prometheus_volume" {
  description = "Named volume for the Prometheus data."
  type        = string
}

variable "prometheus_retention" {
  description = "How long Prometheus keeps samples."
  type        = string
  default     = "15d"
}

variable "scrape_interval" {
  description = "How often Prometheus scrapes targets."
  type        = string
  default     = "15s"
}

variable "postgres_exporter_image" {
  description = "Docker image for the PostgreSQL exporter."
  type        = string
}

variable "postgres_host" {
  description = "PostgreSQL host:port as seen from the data network."
  type        = string
}

variable "postgres_monitoring_password" {
  description = "Password of the 'monitoring' role."
  type        = string
  sensitive   = true
}

variable "minio_target" {
  description = "MinIO host:port as seen from the monitoring network."
  type        = string
}

variable "grafana_image" {
  description = "Docker image for Grafana."
  type        = string
}

variable "grafana_port" {
  description = "Port Grafana binds to."
  type        = number
  default     = 3000
}

variable "grafana_volume" {
  description = "Named volume for Grafana's DB."
  type        = string
}

variable "grafana_admin_user" {
  description = "Grafana admin user."
  type        = string
  default     = "admin"
}

variable "grafana_admin_password" {
  description = "Grafana admin password."
  type        = string
  sensitive   = true
}

variable "statsd_exporter_image" {
  description = "Docker image for the StatsD exporter (Airflow metrics)."
  type        = string
}
