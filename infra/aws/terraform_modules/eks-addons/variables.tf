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

variable "default_tags" {
  type = map(any)
}