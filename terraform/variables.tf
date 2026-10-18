variable "docker_host" {
  description = "Leave null to use DOCKER_HOST / localhost."
  type        = string
  default     = null
}

variable "project_name" {
  description = "Prefix used for every Docker object."
  type        = string
  default     = "sdg"

  # https://github.com/moby/moby/blob/master/daemon/names/names.go
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.project_name))
    error_message = "project_name must be lowercase alphanumeric (dashes allowed)."
  }
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

variable "minio_root_user" {
  description = "MinIO root user."
  type        = string
  default     = "minioadmin"
}

variable "minio_root_password" {
  description = "MinIO root password. Leave null to generate a random one (see `terraform output`)."
  type        = string
  default     = null
  sensitive   = true
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
