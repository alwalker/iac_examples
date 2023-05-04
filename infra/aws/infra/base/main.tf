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
    namecheap = {
      source  = "namecheap/namecheap"
      version = ">= 2.0.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "namecheap" {
  user_name   = "alwalker"
  api_user    = "alwalker"
  use_sandbox = false
}

locals {
  domain_name          = "iac-examples.com"
  bastion_ssh_key_path = "/tmp/bastion_ssh_key"
  enable_eks           = true
}

module "prod" {
  source = "./environment"

  env_name                = "prod"
  centos_stream_version   = "9"
  domain_name             = local.domain_name
  database_admin_username = "acmeadmin"
  app_port                = "6100"
  enable_eks              = local.enable_eks

  default_tags = {
    managed_by_terraform = true
    env                  = "prod"
  }
}

module "eks" {
  count  = local.enable_eks ? 1 : 0
  source = "./eks"

  env_name                  = "prod"
  vpc_id                    = module.prod.vpc.vpc_id
  private_route_table_ids   = module.prod.vpc.private_route_table_ids
  bastion_security_group_id = module.prod.bastion_security_group_id
  outline_security_group_id = module.prod.outline_security_group_id

  default_tags = {
    managed_by_terraform = true
    env                  = "prod"
  }
}

resource "local_sensitive_file" "bastion_ssh_private_key" {
  content  = module.prod.bastion_ssh_private_key
  filename = local.bastion_ssh_key_path
}
resource "local_sensitive_file" "bastion_ssh_public_key" {
  content  = module.prod.bastion_ssh_public_key
  filename = "${local.bastion_ssh_key_path}_pub"
}
data "template_file" "ssh_tunnel_setup_script" {
  template = file("${path.module}/../../setup_bastion_tunnel.tftpl")

  vars = {
    ssh_key_path       = local.bastion_ssh_key_path
    database_host_name = module.prod.database.address
    redis_host_name    = module.prod.redis.cache_nodes[0].address
    bastion_host_ip    = module.prod.bastion.public_ip
    eks_api_host_name  = local.enable_eks ? module.eks[0].api_host_name : ""
  }
}
resource "local_file" "setup_bastion_tunnel_script" {
  content  = data.template_file.ssh_tunnel_setup_script.rendered
  filename = "${path.root}/../../../../ops/aws_setup_bastion_tunnel.sh"
}
