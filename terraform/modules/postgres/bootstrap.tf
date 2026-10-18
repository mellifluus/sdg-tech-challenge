# One-shot psql job that brings the instance to the desired state (databases, users, permissions)
locals {
  db_names = sort(keys(var.databases))

  bootstrap_sql = templatefile("${path.module}/bootstrap.sql.tftpl", {
    databases = local.db_names
  })
}

resource "docker_container" "bootstrap" {
  name     = "${var.name_prefix}-postgres-bootstrap"
  image    = docker_image.postgres.image_id
  must_run = false
  attach   = true
  logs     = true

  entrypoint = ["psql", "-h", "postgres", "-U", "postgres", "-d", "postgres", "-f", "/bootstrap/bootstrap.sql"]

  env = concat(
    [
      "PGPASSWORD=${var.superuser_password}",
      "PGCONNECT_TIMEOUT=10",
      # Re-run the job whenever the server container is replaced.
      "POSTGRES_CONTAINER_ID=${docker_container.postgres.id}",
    ],
    [for db in local.db_names : "PW_${db}=${var.databases[db].password}"],
  )

  upload {
    file    = "/bootstrap/bootstrap.sql"
    content = local.bootstrap_sql
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

  lifecycle {
    postcondition {
      condition     = self.exit_code == 0
      error_message = "PostgreSQL bootstrap job failed (exit code ${coalesce(self.exit_code, -1)}). Check: docker logs ${self.name}"
    }
  }
}
