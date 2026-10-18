data "terraform_remote_state" "foundation" {
  backend = "local"

  config = {
    path = var.foundation_state_path
  }
}

locals {
  foundation = data.terraform_remote_state.foundation.outputs
}
