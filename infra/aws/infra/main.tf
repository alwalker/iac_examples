terraform {
  backend "s3" {
    region         = "us-east-1"
    bucket         = "awsiac-devops"
    key            = "terraform-states/infra"
    dynamodb_table = "terraform-states-infra" #LockID
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

locals {
  domain_name = "alwiac.com"
  bastion_ssh_key_path = "/tmp/bastion_ssh_key"
}

module "prod" {
  source = "./environment"

  env_name                = "prod"
  centos_stream_version   = "8"
  domain_name             = local.domain_name
  database_admin_username = "acmeadmin"
  app_port                = "6100"

  default_tags = {
    managed_by_terraform = true
    env                  = "prod"
  }
}

resource "local_sensitive_file" "bastion_ssh_private_key" {
    content = module.prod.bastion_ssh_private_key
    filename = local.bastion_ssh_key_path
}
resource "local_sensitive_file" "bastion_ssh_public_key" {
    content = module.prod.bastion_ssh_public_key
    filename = "${local.bastion_ssh_key_path}_pub"
}
resource "template_file" "ssh_tunnel_setup_script" {
    template = file("${path.module}/../setup_bastion_tunnel.tftpl")

    vars = {
        ssh_key_path = local.bastion_ssh_key_path
        database_host_name = module.prod.database.address
        # redis_host_name = module.prod.redis
        bastion_host_ip = module.prod.bastion.public_ip
    }
}
resource "local_file" "setup_bastion_tunnel_script" {
    content = template_file.ssh_tunnel_setup_script.rendered
    filename = "${path.module}/../setup_bastion_tunnel.sh"
}
