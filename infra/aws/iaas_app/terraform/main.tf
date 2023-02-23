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
  }
}

provider "aws" {
  region = "us-east-1"
}

data "terraform_remote_state" "infra" {
  backend = "s3"
  config = {
    bucket = "awsiac-devops"
    key    = "terraform-states/infra"
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
