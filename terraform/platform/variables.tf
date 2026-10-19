variable "docker_host" {
  description = "Leave null to use DOCKER_HOST / localhost."
  type        = string
  default     = null
}

variable "foundation_state_path" {
  description = "Path to the foundation layer state (local backend)."
  type        = string
  default     = "../foundation/terraform.tfstate"
}

variable "bind_address" {
  description = "Host address the published ports bind to."
  type        = string
  default     = "127.0.0.1"
}

# MINIO

variable "minio_image" {
  description = <<-EOT
    MinIO server image. MinIO stopped publishing community images to Docker Hub/Quay.
    Using Chainguard's build, pinned by digest.
  EOT
  type        = string
  default     = "cgr.dev/chainguard/minio@sha256:2136d593beacf4461187035eca949fe49abd589d5079735025c711ca58fee0c8"
}

variable "minio_api_port" {
  description = "Host port for the MinIO API."
  type        = number
  default     = 9000
}

variable "minio_console_port" {
  description = "Host port for the MinIO web console."
  type        = number
  default     = 9001
}

variable "minio_mc_image" {
  description = "MinIO client image (this one has a shell for the bootstrap script)."
  type        = string
  default     = "cgr.dev/chainguard/minio-client@sha256:cd7f5d19d115615d809f27343b1e5cfbdc84f38e1c9a29475535b74ec5bade50"
}

variable "minio_buckets" {
  description = "Buckets created by the bootstrap job."
  type        = list(string)
  default     = ["data-bucket"]
}

variable "minio_app_user" {
  description = "Least-privilege MinIO user."
  type        = string
  default     = "app"
}

# POSTGRESQL

variable "postgres_image" {
  description = "PostgreSQL image."
  type        = string
  default     = "postgres:17.6-alpine"
}

variable "postgres_port" {
  description = "Host port for PostgreSQL."
  type        = number
  default     = 5432
}

variable "orchestrator_db_name" {
  description = "Database (and owner role) holding the orchestrator metadata."
  type        = string
  default     = "airflow"
}

variable "warehouse_db_name" {
  description = "Destination database (and owner role) where pipelines load data."
  type        = string
  default     = "warehouse"
}

# MONITORING

variable "prometheus_image" {
  description = "Prometheus image."
  type        = string
  default     = "prom/prometheus:v3.5.0"
}

variable "prometheus_port" {
  description = "Host port for the Prometheus UI / API."
  type        = number
  default     = 9090
}

variable "prometheus_retention" {
  description = "Prometheus db retention."
  type        = string
  default     = "15d"
}

variable "postgres_exporter_image" {
  description = "Prometheus PostgreSQL exporter image."
  type        = string
  default     = "prometheuscommunity/postgres-exporter:v0.18.1"
}

variable "grafana_image" {
  description = "Grafana image."
  type        = string
  default     = "grafana/grafana:12.2.0"
}

variable "grafana_port" {
  description = "Host port for the Grafana UI."
  type        = number
  default     = 3000
}

variable "grafana_admin_user" {
  description = "Grafana admin user."
  type        = string
  default     = "admin"
}
