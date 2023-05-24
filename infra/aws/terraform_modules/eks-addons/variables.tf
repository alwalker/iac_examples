variable "env_name" {
  type = string
}
variable "eks_oidc_provider_arn" {
  type = string
}
variable "aws_region_name" {
  type = string
}

variable "dns_zone_arn" {
  type = string
}
variable "dns_zone_name" {
  type = string
}
variable "acm_cert_arn" {
  type = string
}

variable "eks_cluster_name" {
  type = string
}
variable "eks_default_node_group_iam_role_arn" {
  type = string
}
variable "eks_default_node_group_guid" {
  type = string
}

variable "outline_security_group_id" {
  type = string
}

variable "default_tags" {
  type = map(any)
}