terraform {
  backend "s3" {
    region         = "us-east-1"
    bucket         = "awsiac-devops"
    key            = "terraform-states/infra-kubernetes"
    dynamodb_table = "terraform-states-infra-kubernetes" #LockID
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
  }
}

locals {
  default_tags = {
    managed_by_terraform = true
    env                  = "prod"
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

data "aws_eks_cluster_auth" "main" {
  name = data.terraform_remote_state.infra.outputs.eks.eks.cluster_name
}
provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.infra.outputs.eks.eks.cluster_endpoint
    token                  = data.aws_eks_cluster_auth.main.token
    cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.eks.eks.cluster_certificate_authority_data)
  }
}
