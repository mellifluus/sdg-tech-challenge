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
    condition     = can(regex("^[a-z][a-z0-9-]$", var.project_name))
    error_message = "project_name must be lowercase alphanumeric (dashes allowed)."
  }
}

variable "bind_address" {
  description = "Host address the published ports bind to."
  type        = string
  default     = "127.0.0.1"
}
