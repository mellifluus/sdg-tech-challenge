variable "name_prefix" {
  description = "Prefix for container/volume names."
  type        = string
}

variable "image" {
  description = "PostgreSQL image."
  type        = string
}

variable "network_name" {
  description = "Docker network the container joins."
  type        = string
}

variable "bind_address" {
  description = "Host IP the port binds to."
  type        = string
}

variable "port" {
  description = "Host port for PostgreSQL."
  type        = number
  default     = 5432
}

variable "superuser_password" {
  description = "Password of the 'postgres' superuser."
  type        = string
  sensitive   = true
}

variable "databases" {
  description = "Databases to create, with optional description."
  type = map(object({
    description = string
    password    = string
  }))
  sensitive = true
}

variable "labels" {
  description = "Labels applied to every Docker object."
  type        = map(string)
  default     = {}
}

variable "volume_name" {
  description = "Pre-existing Docker volume for the data dir (owned by the foundation layer)."
  type        = string
}
