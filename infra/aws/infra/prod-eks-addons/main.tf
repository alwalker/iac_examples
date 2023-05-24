terraform {
  backend "s3" {
    region         = "us-east-1"
    bucket         = "awsiac-devops"
    key            = "terraform-states/infra-prod-kubernetes"
    dynamodb_table = "terraform-states-infra-prod-kubernetes" #LockID
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.19.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.9.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_region" "current" {}

data "terraform_remote_state" "infra" {
  backend = "s3"
  config = {
    bucket = "awsiac-devops"
    key    = "terraform-states/infra"
    region = "us-east-1"
  }
}

data "aws_eks_cluster_auth" "main" {
  name = data.terraform_remote_state.infra.outputs.eks[0].eks.cluster_name
}
provider "kubernetes" {
  host                   = data.terraform_remote_state.infra.outputs.eks[0].eks.cluster_endpoint
  token                  = data.aws_eks_cluster_auth.main.token
  cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.eks[0].eks.cluster_certificate_authority_data)
}
provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.infra.outputs.eks[0].eks.cluster_endpoint
    token                  = data.aws_eks_cluster_auth.main.token
    cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.eks[0].eks.cluster_certificate_authority_data)
  }
}

module "add_ons" {
  source = "../../terraform_modules/eks-addons"

  env_name                            = "prod"
  eks_oidc_provider_arn               = data.terraform_remote_state.infra.outputs.eks[0].eks.oidc_provider_arn
  aws_region_name                     = data.aws_region.current.name
  dns_zone_arn                        = data.terraform_remote_state.infra.outputs.prod.dns_zone.arn
  dns_zone_name                       = data.terraform_remote_state.infra.outputs.prod.dns_zone.name
  acm_cert_arn                        = data.terraform_remote_state.infra.outputs.prod.acm_cert_arn
  eks_cluster_name                    = data.terraform_remote_state.infra.outputs.eks[0].eks.cluster_name
  eks_default_node_group_iam_role_arn = data.terraform_remote_state.infra.outputs.eks[0].eks.eks_managed_node_groups["default"].iam_role_arn
  eks_default_node_group_guid = element(
    split("/", data.terraform_remote_state.infra.outputs.eks[0].eks.eks_managed_node_groups["default"].node_group_arn),
    length(split("/", data.terraform_remote_state.infra.outputs.eks[0].eks.eks_managed_node_groups["default"].node_group_arn)) - 1
  )
  outline_security_group_id = data.terraform_remote_state.infra.outputs.prod.outline_security_group_id

  default_tags = {
    managed_by_terraform = true
    env                  = "prod"
  }
}
