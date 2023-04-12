terraform {
  required_providers {
    shell = {
      source = "scottwinkler/shell"
    }
  }
}
data "shell_script" "main" {
  lifecycle_commands {
    read = "${path.module}/get_centos_ami.sh"
  }

  environment = {
    AWS_REGION   = var.region,
    VERSION      = var.centos_version_number,
    ARCHITECTURE = var.architecture
  }
}