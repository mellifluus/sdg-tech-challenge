variable "name_prefix" {
  description = "Prefix for container/volume names."
  type        = string
}

variable "image" {
  description = "MinIO server image (possibly pinned by digest)."
  type        = string
}

variable "network_name" {
  description = "Docker network the container joins."
  type        = string
}

variable "root_user" {
  description = "MinIO root user."
  type        = string
}

variable "root_password" {
  description = "MinIO root password."
  type        = string
  sensitive   = true
}

variable "bind_address" {
  description = "Host IP the ports bind to."
  type        = string
}

variable "api_port" {
  description = "Host port for the API."
  type        = number
  default     = 9000
}

variable "console_port" {
  description = "Host port for the web console."
  type        = number
  default     = 9001
}

variable "labels" {
  description = "Labels applied to every Docker object."
  type        = map(string)
  default     = {}
}
