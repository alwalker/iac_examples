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
    shell = {
      source = "scottwinkler/shell"
    }
    ignition = {
      source  = "community-terraform-providers/ignition"
      version = "2.1.3"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "ignition" {}

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
  bucket = "awsiac-outline-prod"
}
resource "aws_s3_bucket_acl" "main" {
  bucket = aws_s3_bucket.main.id
  acl    = "private"
}

resource "aws_cloudwatch_log_group" "main" {
  name = "outline-prod"

  retention_in_days = 7

  tags = local.default_tags
}

module "alb_endpoint" {
  source = "../../terraform_modules/alb"

  name          = "outline"
  port          = local.outline_port
  target_type   = "instance"
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
  source = "../../terraform_modules/database"

  name = "outline"

  default_tags = local.default_tags
}

module "cognito" {
  source = "../../terraform_modules/cognito"

  name = "outline-prod"

  certificate_arn  = data.terraform_remote_state.infra.outputs.prod.acm_cert_arn
  base_domain_name = data.terraform_remote_state.infra.outputs.prod_domain_name

  dns_zone_id = data.terraform_remote_state.infra.outputs.prod.dns_zone.id

  callback_urls = ["${local.dns_name}/auth/oidc.callback"]
}

module "iam" {
  source = "./iam"

  name                      = "outline"
  env_name                  = "prod"
  app_port                  = local.outline_port
  outline_security_group_id = data.terraform_remote_state.infra.outputs.prod.outline_security_group_id
  alb_security_group_id     = data.terraform_remote_state.infra.outputs.prod.alb_security_group_id
  bastion_security_group_id = data.terraform_remote_state.infra.outputs.prod.bastion_security_group_id

  bucket_name     = aws_s3_bucket.main.id
  outline_ecr_arn = data.terraform_remote_state.cicd.outputs.outline_ecr_arn

  default_tags = local.default_tags
}

module "asg" {
  source = "./asg"

  name                      = "outline"
  env_name                  = "prod"
  cicd_bucket_name          = data.terraform_remote_state.cicd.outputs.cicd_bucket_name
  instance_size             = "t3a.nano"
  security_group_ids        = [data.terraform_remote_state.infra.outputs.prod.outline_security_group_id]
  root_volume_size          = 20
  iam_profile_arn           = module.iam.iam_instance_profile_name
  max_instance_count        = 2
  min_instance_count        = 1
  health_check_grace_period = 30
  base_instance_count       = 1
  private_subnets           = data.terraform_remote_state.infra.outputs.prod.vpc.private_subnets
  target_groups             = [module.alb_endpoint.target_group_arn]
  asg_cpu_max_threshold     = 80
  asg_cpu_min_threshold     = 40
  default_tags              = local.default_tags

  outline_container_image_uri = data.terraform_remote_state.cicd.outputs.outline_ecr_uri
  port                        = local.outline_port
  outline_registry_domain     = split("/", data.terraform_remote_state.cicd.outputs.outline_ecr_uri)[0]
  database_password           = module.database.password
  database_username           = module.database.username
  database_host               = data.terraform_remote_state.infra.outputs.prod.database.address
  redis_host                  = data.terraform_remote_state.infra.outputs.prod.redis.cache_nodes[0].address
  outline_url                 = local.dns_name
  bucket_name                 = aws_s3_bucket.main.id
  oidc_client_id              = module.cognito.client.id
  oidc_client_secret          = module.cognito.client.client_secret
  oidc_auth_url               = module.cognito.oauth_info["authorization_endpoint"]
  oidc_token_uri              = module.cognito.oauth_info["token_endpoint"]
  oidc_userinfo_uri           = module.cognito.oauth_info["userinfo_endpoint"]
}

data "aws_ami" "fedora_coreos" {
  owners      = ["125523088429"]
  most_recent = true

  filter {
    name   = "name"
    values = ["fedora-coreos-37*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "test_instance" {
  ami                         = data.aws_ami.fedora_coreos.id
  instance_type               = "t3a.medium"
  vpc_security_group_ids      = [data.terraform_remote_state.infra.outputs.prod.outline_security_group_id]
  subnet_id                   = data.terraform_remote_state.infra.outputs.prod.vpc.private_subnets[0]
  associate_public_ip_address = false
  iam_instance_profile        = module.iam.iam_instance_profile_name
  user_data                   = module.asg.ignition_file
  user_data_replace_on_change = true

  root_block_device {
    volume_type = "gp3"
    encrypted   = true
  }

  lifecycle {
    ignore_changes = [ami]
  }

  tags = merge({ Name = "test instance" }, local.default_tags)
}
output "test_host" {
  value = aws_instance.test_instance.private_dns
}
output "ignition_file" {
  value = jsondecode(module.asg.ignition_file)
}
