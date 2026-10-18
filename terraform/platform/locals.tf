locals {
  common_labels = {
    "com.sdg.project"    = local.foundation.project_name
    "com.sdg.managed-by" = "terraform"
    "com.sdg.layer"      = "platform"
  }
}
