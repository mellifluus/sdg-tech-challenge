variable "docker_host" {
  description = "Leave null to use DOCKER_HOST / localhost."
  type        = string
  default     = null
}

variable "project_name" {
  description = "Prefix used for every Docker object (inherited by the platform layer)."
  type        = string
  default     = "sdg"

  # https://github.com/moby/moby/blob/master/daemon/names/names.go
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.project_name))
    error_message = "project_name must be lowercase alphanumeric (dashes allowed)."
  }
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
