output "eks_control_plane_subnets_cidr" {
  value = local.eks_control_plane_subnets
}
output "eks_node_subnets_cidr" {
  value = local.eks_node_subnets
}
output "eks_control_plane_subnets" {
  value = module.eks_control_plane_subnets
}
output "eks_node_subnets" {
  value = module.eks_node_subnets
}

output "eks" {
  value = module.eks
}
output "api_host_name" {
  value = split("https://", module.eks.cluster_endpoint)[1]
}

output "primary_alb_group_name" {
  value = "main"
}