locals {
  num_azs = length(var.vpc_availability_zones)

  private_subnets     = length(var.vpc_private_subnets) == 0 ? [for i in range(local.num_azs) : cidrsubnet(var.vpc_cidr, 8, i + var.vpc_private_subnet_offset)] : var.vpc_private_subnets
  dabatase_subnets    = length(var.vpc_database_subnets) == 0 ? [for i in range(local.num_azs) : cidrsubnet(var.vpc_cidr, 8, i + var.vpc_database_subnet_offset)] : var.vpc_database_subnets
  public_subnets      = length(var.vpc_public_subnets) == 0 ? [for i in range(local.num_azs) : cidrsubnet(var.vpc_cidr, 8, i + var.vpc_public_subnet_offset)] : var.vpc_public_subnets
  elasticache_subnets = length(var.vpc_elasticache_subnets) == 0 ? [for i in range(local.num_azs) : cidrsubnet(var.vpc_cidr, 8, i + var.vpc_elasticache_subnet_offset)] : var.vpc_elasticache_subnets
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.19.0"

  name = var.env_name
  cidr = var.vpc_cidr

  azs                 = var.vpc_availability_zones
  private_subnets     = local.private_subnets
  database_subnets    = local.dabatase_subnets
  public_subnets      = local.public_subnets
  elasticache_subnets = local.elasticache_subnets

  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = var.default_tags
}

resource "aws_route53_zone" "main" {
  name = var.domain_name
}