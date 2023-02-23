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
}

module "prod" {
  source = "./environment"

  env_name                = "prod"
  centos_stream_version   = "9"
  domain_name             = local.domain_name
  database_admin_username = "acmeadmin"
  app_port                = "6100"

  default_tags = {
    managed_by_terraform = true
    env                  = "prod"
  }
}
