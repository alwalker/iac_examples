variable "name" {
  type = string
}

variable "iam_role_arn" {
  type = string
}
variable "outline_container_image_uri" {
  type = string
}
variable "database_username" {
  type = string
}
variable "database_password" {
  type = string
}
variable "database_host" {
  type = string
}
variable "redis_host" {
  type = string
}
variable "outline_url" {
  type = string
}
variable "bucket_name" {
  type = string
}
variable "oidc_client_id" {
  type = string
}
variable "oidc_client_secret" {
  type = string
}
variable "oidc_auth_url" {
  type = string
}
variable "oidc_token_uri" {
  type = string
}
variable "oidc_userinfo_uri" {
  type = string
}
variable "cloudwatch_group_name" {
  type = string
}
variable "log_region" {
  type = string
}
variable "execution_role_arn" {
  type = string
}

variable "cluster_arn" {
  type = string
}
variable "force_new_deployment" {
  type    = bool
  default = false
}
variable "target_group_arn" {
  type = string
}
variable "app_port" {
  type = number
}
variable "subnets" {
  type = list(string)
}
variable "security_groups" {
  type = list(string)
}

variable "default_tags" {
  type = map(any)
}
