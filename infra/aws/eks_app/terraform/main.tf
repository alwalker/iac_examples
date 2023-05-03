terraform {
  backend "s3" {
    region         = "us-east-1"
    bucket         = "awsiac-devops"
    key            = "terraform-states/outline-eks-prod"
    dynamodb_table = "terraform-states-outline-eks-prod" #LockID
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.9.0"
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

data "aws_region" "current" {}
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

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

data "aws_eks_cluster_auth" "main" {
  name = data.terraform_remote_state.infra.outputs.eks[0].eks.cluster_name
}
provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.infra.outputs.eks[0].eks.cluster_endpoint
    token                  = data.aws_eks_cluster_auth.main.token
    cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.eks[0].eks.cluster_certificate_authority_data)
  }
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

locals {
  env_name         = "prod"
  outline_port     = 3000
  outline_dns_name = "outline-prod.${data.terraform_remote_state.infra.outputs.prod_domain_name}"

  default_tags = {
    managed_by_terraform = true
    env                  = "prod"
  }
}

module "cognito_client" {
  source = "../../terraform_modules/cognito_client"

  name            = "outline-prod"
  cognito_pool_id = data.terraform_remote_state.infra.outputs.prod.cognito.user_pool.id

  callback_urls = ["https://${local.outline_dns_name}/auth/oidc.callback"]
}

module "database" {
  source = "../../terraform_modules/database"

  name = "outline"

  default_tags = local.default_tags
}
