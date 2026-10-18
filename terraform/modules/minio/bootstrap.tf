# One-shot job that brings MinIO to the desired state (buckets, policy, app user)
resource "docker_image" "mc" {
  name         = var.mc_image
  keep_locally = true
}

locals {
  app_policy_name = "app-rw"

  # R/W limited to the managed buckets only
  app_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetBucketLocation", "s3:ListBucket", "s3:ListBucketMultipartUploads"]
        Resource = [for b in var.buckets : "arn:aws:s3:::${b}"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts"]
        Resource = [for b in var.buckets : "arn:aws:s3:::${b}/*"]
      },
    ]
  })

  bootstrap_script = templatefile("${path.module}/bootstrap.sh.tftpl", {
    buckets      = join(" ", var.buckets)
    app_user     = var.app_user
    app_password = var.app_password
    policy_name  = local.app_policy_name
  })
}

resource "docker_container" "bootstrap" {
  name     = "${var.name_prefix}-minio-bootstrap"
  image    = docker_image.mc.image_id
  must_run = false
  attach   = true
  logs     = true

  entrypoint = ["/bin/sh", "/bootstrap/bootstrap.sh"]

  env = [
    "MC_HOST_local=http://${var.root_user}:${var.root_password}@minio:9000",
    "APP_USER_PASSWORD=${var.app_password}",
    # Re-run the job whenever the server container is replaced.
    "MINIO_CONTAINER_ID=${docker_container.minio.id}",
  ]

  upload {
    file    = "/bootstrap/bootstrap.sh"
    content = local.bootstrap_script
  }

  upload {
    file    = "/bootstrap/policy.json"
    content = local.app_policy
  }

  networks_advanced {
    name = var.network_name
  }

  dynamic "labels" {
    for_each = var.labels
    content {
      label = labels.key
      value = labels.value
    }
  }

  timeouts {
    create = "60s"
  }

  lifecycle {
    postcondition {
      condition     = self.exit_code == 0
      error_message = "MinIO bootstrap job failed (exit code ${coalesce(self.exit_code, -1)}). run docker logs ${self.name}"
    }
  }
}
