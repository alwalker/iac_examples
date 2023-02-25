terraform {
  backend "s3" {
    region         = "us-east-1"
    bucket         = "awsiac-devops"
    key            = "terraform-states/outline-prod"
    dynamodb_table = "terraform-states-outline-prod"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "~> 1.18.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "postgresql" {
  host            = data.terraform_remote_state.infra.outputs.prod.database.address
  port            = 5432
  database        = "postgres"
  username        = data.terraform_remote_state.infra.outputs.prod.database_admin_username
  password        = data.terraform_remote_state.infra.outputs.prod.database_admin_password
  sslmode         = "require"
  superuser       = false
  connect_timeout = 15
}

data "terraform_remote_state" "infra" {
  backend = "s3"
  config = {
    bucket = "awsiac-devops"
    key    = "terraform-states/infra"
    region = "us-east-1"
  }
}
data "terraform_remote_state" "cicd" {
  backend = "s3"
  config = {
    bucket = "awsiac-devops"
    key    = "terraform-states/cicd"
    region = "us-east-1"
  }
}

locals {
  default_tags = {
    managed_by_terraform = true
    env                  = "prod"
  }
}

module "alb_endpoint" {
  source = "./alb"

  name          = "outline"
  port          = "6100"
  vpc_id        = data.terraform_remote_state.infra.outputs.prod.vpc.vpc_id
  listener_arn  = data.terraform_remote_state.infra.outputs.prod.alb_https_listener.arn
  priority      = "1000"
  host_headers  = ["outline.${data.terraform_remote_state.infra.outputs.domain_name}"]
  hostedzone_id = data.terraform_remote_state.infra.outputs.prod.dns_zone.zone_id
  dns_name      = "outline"
  alb_dns_name  = data.terraform_remote_state.infra.outputs.prod.alb.dns_name
  alb_dns_zone  = data.terraform_remote_state.infra.outputs.prod.alb.zone_id
  default_tags  = local.default_tags
}

module "database" {
  source = "./database"

  name = "outline"

  default_tags = local.default_tags
}

module "iam" {
  source = "./iam"

  name             = "outline"
  cicd_bucket_name = data.terraform_remote_state.cicd.outputs.cicd_bucket_name

  default_tags = local.default_tags
}

module "asg" {
  source = "./asg"

  name                      = "outline"
  aminame                   = "notyet"
  env_name                  = "prod"
  cicd_bucket_name          = data.terraform_remote_state.cicd.outputs.cicd_bucket_name
  instance_size             = "t3a.nano"
  security_group_ids        = [data.terraform_remote_state.infra.outputs.prod.outline_security_group_id]
  root_volume_size          = 20
  iam_profile_arn           = module.iam.iam_profile_arn
  max_instance_count        = 2
  min_instance_count        = 1
  health_check_grace_period = 30
  base_instance_count       = 1
  private_subnets           = data.terraform_remote_state.infra.outputs.prod.vpc.private_subnets
  target_groups             = [module.alb_endpoint.target_group_arn]
  asg_cpu_max_threshold     = 80
  asg_cpu_min_threshold     = 40
  default_tags              = local.default_tags
}
