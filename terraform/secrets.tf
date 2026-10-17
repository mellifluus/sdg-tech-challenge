resource "random_password" "minio_root" {
  length  = 24
  special = false
}

locals {
  minio_root_password = coalesce(var.minio_root_password, random_password.minio_root.result)
}