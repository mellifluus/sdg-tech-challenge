variable "name_prefix" {
  description = "Prefix for container/image names."
  type        = string
}

variable "base_image" {
  description = "Official Airflow image the local image is built from."
  type        = string
}

variable "network_name" {
  description = "Docker network the containers join."
  type        = string
}

variable "bind_address" {
  description = "Host IP the Airflow UI port binds to."
  type        = string
}

variable "port" {
  description = "Host port for the Airflow UI / REST API."
  type        = number
  default     = 8080
}

variable "labels" {
  description = "Labels applied to every Docker object."
  type        = map(string)
  default     = {}
}

variable "logs_volume" {
  description = "Docker volume for task logs."
  type        = string
}

variable "admin_user" {
  description = "Airflow admin user."
  type        = string
  default     = "admin"
}

variable "admin_password" {
  description = "Airflow admin password."
  type        = string
  sensitive   = true
}

variable "fernet_key" {
  description = "Fernet key encrypting secrets in the metadata DB."
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "Secret signing the api-server JWTs."
  type        = string
  sensitive   = true
}

variable "postgres_host" {
  description = "PostgreSQL hostname on the data network."
  type        = string
}

variable "metadata_db" {
  description = "Database holding the Airflow metadata."
  type        = string
}

variable "metadata_password" {
  description = "Password of the metadata DB role."
  type        = string
  sensitive   = true
}
