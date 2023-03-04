terraform {
  backend "s3" {
    region         = "us-east-1"
    bucket         = "awsiac-devops"
    key            = "terraform-states/outline-fargate-prod"
    dynamodb_table = "terraform-states-outline-fargate-prod"
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
  outline_port = 3000
  dns_name     = "https://outline-prod.${data.terraform_remote_state.infra.outputs.prod_domain_name}"
  oidc_url     = "https://oidc.${data.terraform_remote_state.infra.outputs.prod_domain_name}"
  default_tags = {
    managed_by_terraform = true
    env                  = "prod"
  }
}

resource "aws_s3_bucket" "main" {
  bucket = "awsiac-outline-prod2"
}
resource "aws_s3_bucket_acl" "main" {
  bucket = aws_s3_bucket.main.id
  acl    = "private"
}

module "alb_endpoint" {
  source = "./alb"

  name          = "outline"
  port          = local.outline_port
  vpc_id        = data.terraform_remote_state.infra.outputs.prod.vpc.vpc_id
  listener_arn  = data.terraform_remote_state.infra.outputs.prod.alb_https_listener.arn
  priority      = "1000"
  host_headers  = ["outline-prod.${data.terraform_remote_state.infra.outputs.prod_domain_name}"]
  hostedzone_id = data.terraform_remote_state.infra.outputs.prod.dns_zone.zone_id
  dns_name      = "outline-prod"
  alb_dns_name  = data.terraform_remote_state.infra.outputs.prod.alb.dns_name
  alb_dns_zone  = data.terraform_remote_state.infra.outputs.prod.alb.zone_id
  default_tags  = local.default_tags
}

module "database" {
  source = "./database"

  name = "outline"

  default_tags = local.default_tags
}

module "security" {
  source = "./security"

  name = "prod-outline"

  app_port                  = local.outline_port
  outline_security_group_id = data.terraform_remote_state.infra.outputs.prod.outline_security_group_id
  alb_security_group_id     = data.terraform_remote_state.infra.outputs.prod.alb_security_group_id

  bucket_name = aws_s3_bucket.main.id

  default_tags = local.default_tags
}

resource "aws_cloudwatch_log_group" "main" {
  name = "outline-prod"

  retention_in_days = 7

  tags = local.default_tags
}

module "cognito" {
  source = "./cognito"

  name = "outline-prod"

  certificate_arn  = data.terraform_remote_state.infra.outputs.prod.acm_cert_arn
  base_domain_name = data.terraform_remote_state.infra.outputs.prod_domain_name

  dns_zone_id = data.terraform_remote_state.infra.outputs.prod.dns_zone.id

  callback_urls = ["${local.dns_name}/auth/oidc.callback"]
}

module "ecs" {
  source = "./ecs"
  depends_on = [
    module.security
  ]

  name = "outline"

  cluster_arn          = data.terraform_remote_state.infra.outputs.prod.ecs_cluster.arn
  force_new_deployment = true
  target_group_arn     = module.alb_endpoint.target_group_arn
  app_port             = local.outline_port
  subnets              = data.terraform_remote_state.infra.outputs.prod.vpc.private_subnets
  security_groups      = [data.terraform_remote_state.infra.outputs.prod.outline_security_group_id]

  iam_role_arn                = module.security.task_role_arn
  outline_container_image_uri = data.terraform_remote_state.cicd.outputs.outline_ecr_uri
  database_password           = module.database.password
  database_username           = module.database.username
  database_host               = data.terraform_remote_state.infra.outputs.prod.database.address
  redis_host                  = data.terraform_remote_state.infra.outputs.prod.redis.cache_nodes[0].address
  outline_url                 = local.dns_name
  bucket_name                 = aws_s3_bucket.main.id
  oidc_client_id              = module.cognito.client.id
  oidc_client_secret          = module.cognito.client.client_secret
  oidc_auth_url               = "${local.oidc_url}/oauth2/authorize"
  oidc_token_uri              = "${local.oidc_url}/oauth2/token"
  oidc_userinfo_uri           = "${local.oidc_url}/oauth2/userInfo"
  cloudwatch_group_name       = aws_cloudwatch_log_group.main.name
  log_region                  = "us-east-1"
  execution_role_arn          = module.security.task_execution_role_arn
  cicd_username               = data.terraform_remote_state.cicd.outputs.cicd_containers_username

  default_tags = local.default_tags
}
