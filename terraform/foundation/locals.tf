locals {
  common_labels = {
    "com.sdg.project"    = var.project_name
    "com.sdg.managed-by" = "terraform"
    "com.sdg.layer"      = "foundation"
  }
}
