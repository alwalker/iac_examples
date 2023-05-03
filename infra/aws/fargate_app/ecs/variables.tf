variable "name" {
  type = string
}
variable "env_name" {
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
variable "bucket_url" {
  type = string
}
variable "bucket_max_upload_size" {
  type = number
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

variable "cicd_username" {
  type = string
}

variable "cluster_name" {
  type = string
}
variable "minimum_service_count" {
  type    = number
  default = 1
}
variable "maximum_service_count" {
  type    = number
  default = 10
}
variable "minimum_service_cpu_threshold" {
  type    = number
  default = 40
}
variable "maximum_service_cpu_threshold" {
  type    = number
  default = 80
}

variable "default_tags" {
  type = map(any)
}
