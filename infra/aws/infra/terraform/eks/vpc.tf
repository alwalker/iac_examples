locals {
  num_azs                   = length(var.vpc_availability_zones)
  eks_control_plane_subnets = length(var.vpc_eks_control_plane_subnets) == 0 ? [for i in range(local.num_azs) : cidrsubnet(var.vpc_cidr, 8, i + var.vpc_eks_control_plane_subnet_offset)] : var.vpc_eks_control_plane_subnets
  eks_node_subnets          = length(var.vpc_eks_node_subnets) == 0 ? [for i in range(local.num_azs) : cidrsubnet(var.vpc_cidr, 4, i + var.vpc_eks_node_subnet_offset)] : var.vpc_eks_node_subnets
}

module "eks_control_plane_subnets" {
  source = "../../../terraform_modules/vpc_subnet"
  count  = length(local.eks_control_plane_subnets)

  name              = "eks-control-plane-${var.vpc_availability_zones[count.index]}"
  availability_zone = var.vpc_availability_zones[count.index]
  cidr_block        = local.eks_control_plane_subnets[count.index]
  vpc_id            = var.vpc_id
  route_table_id    = var.single_nat_gateway ? var.private_route_table_ids[0] : var.private_route_table_ids[count.index]

  default_tags = merge({ type = "eks-control-plane" }, var.default_tags)
}

module "eks_node_subnets" {
  source = "../../../terraform_modules/vpc_subnet"
  count  = length(local.eks_node_subnets)

  name              = "eks-nodes-${var.vpc_availability_zones[count.index]}"
  availability_zone = var.vpc_availability_zones[count.index]
  cidr_block        = local.eks_node_subnets[count.index]
  vpc_id            = var.vpc_id
  route_table_id    = var.single_nat_gateway ? var.private_route_table_ids[0] : var.private_route_table_ids[count.index]

  default_tags = merge({ type = "eks-node" }, var.default_tags)
}
