variable "vpc_availability_zones" {
  type = list(string)
  default = [
    "us-east-1a",
    "us-east-1b",
    "us-east-1c",
    "us-east-1d",
    "us-east-1e",
    "us-east-1f"
  ]
}
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "vpc_id" {
  type = string
}
variable "private_route_table_ids" {
  type = list(string)
}
variable "single_nat_gateway" {
  type    = bool
  default = true
}
variable "bastion_security_group_id" {
  type = string
}
variable "vpc_eks_control_plane_subnets" {
  type    = list(string)
  default = []
}
variable "vpc_eks_node_subnets" {
  type    = list(string)
  default = []
}
variable "vpc_eks_control_plane_subnet_offset" {
  type    = number
  default = 120
}
variable "vpc_eks_node_subnet_offset" {
  type    = number
  default = 8
}
variable "env_name" {
  type = string
}
variable "ssh_port" {
  type    = string
  default = 22
}
variable "kubernetes_version" {
  type    = string
  default = "1.26"
}
variable "outline_security_group_id" {
  type = string
}


variable "default_tags" {
  type = map(any)
}

