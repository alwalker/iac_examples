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
  outline_port = 3000
  dns_name     = "https://outline-prod.${data.terraform_remote_state.infra.outputs.prod_domain_name}"
  oidc_url     = "https://oidc.${data.terraform_remote_state.infra.outputs.prod_domain_name}"
  default_tags = {
    managed_by_terraform = true
    env                  = "prod"
  }
}

module "s3" {
  source = "../../terraform_modules/outline_s3_bucket"

  env_name = "prod"
  base_url = local.dns_name

  default_tags = local.default_tags
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

module "iam" {
  source = "./iam"

  outline_security_group_id = data.terraform_remote_state.infra.outputs.prod.outline_security_group_id
  alb_security_group_id     = data.terraform_remote_state.infra.outputs.prod.alb_security_group.id
  bastion_security_group_id = data.terraform_remote_state.infra.outputs.prod.bastion_security_group_id
  app_port                  = local.outline_port

  name                      = "outline"
  cicd_bucket_name          = data.terraform_remote_state.cicd.outputs.cicd_bucket_name
  outline_bucket_policy_arn = module.s3.iam_policy.arn

  default_tags = local.default_tags
}

module "cognito_client" {
  source = "../../terraform_modules/cognito_client"

  name            = "outline-prod"
  cognito_pool_id = data.terraform_remote_state.infra.outputs.prod.cognito.user_pool.id

  callback_urls = ["${local.dns_name}/auth/oidc.callback"]
}

module "cloudwatch" {
  source = "./cloudwatch"

  name        = "outline"
  env_name    = "prod"
  bucket_name = data.terraform_remote_state.cicd.outputs.cicd_bucket_name

  default_tags = local.default_tags
}

module "asg" {
  source = "./asg"
  depends_on = [
    module.cloudwatch,
    module.database
  ]

  name     = "outline"
  env_name = "prod"

  ami_name = "outline-*"

  instance_size             = "t3a.medium"
  security_group_ids        = [data.terraform_remote_state.infra.outputs.prod.outline_security_group_id]
  root_volume_size          = 20
  iam_profile_arn           = module.iam.instance_profile.arn
  iam_profile_name          = module.iam.instance_profile.name
  max_instance_count        = 2
  min_instance_count        = 1
  health_check_grace_period = 360
  base_instance_count       = 1
  availability_zones        = data.terraform_remote_state.infra.outputs.prod.vpc.azs
  vpc_id                    = data.terraform_remote_state.infra.outputs.prod.vpc.vpc_id
  target_group_arn          = module.alb_endpoint.target_group_arn
  target_group_arns         = [module.alb_endpoint.target_group_arn]
  asg_cpu_max_threshold     = 80
  asg_cpu_min_threshold     = 40
  default_tags              = local.default_tags
}

# resource "aws_instance" "test_instance" {
#   depends_on = [
#     module.cloudwatch
#   ]

#   ami                         = "ami-0fb5beb1fe0e14a2a"
#   instance_type               = "t3a.medium"
#   vpc_security_group_ids      = [data.terraform_remote_state.infra.outputs.prod.outline_security_group_id]
#   subnet_id                   = data.terraform_remote_state.infra.outputs.prod.vpc.private_subnets[0]
#   key_name                    = "prod-bastion"
#   iam_instance_profile        = module.iam.instance_profile.name
#   user_data_replace_on_change = true
#   user_data                   = <<-EOT
#   #!/usr/bin/bash -xe
#   echo -n "prod" | sudo -u outline tee /opt/outline/env_name
#   sudo -iu outline bash /opt/outline/get_configs.sh
#   EOT

#   root_block_device {
#     volume_type = "gp3"
#     encrypted   = true
#   }

#   tags = merge({ Name = "test instance" }, local.default_tags)
# }

# output "test_ip" {
#   value = aws_instance.test_instance.private_ip
# }
