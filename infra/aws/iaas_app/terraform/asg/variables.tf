variable "name" {
  type = string
}


variable "env_name" {
  type = string
}
variable "cicd_bucket_name" {
  type = string
}

variable "instance_size" {
  type = string
}
variable "security_group_ids" {
  type = list(any)
}
variable "root_volume_size" {
  type = number
}
variable "iam_profile_arn" {
  type = string
}

variable "max_instance_count" {
  type = string
}
variable "min_instance_count" {
  type = string
}
variable "health_check_grace_period" {
  type = number
}
variable "base_instance_count" {
  type = string
}
variable "private_subnets" {
  type = list(any)
}
variable "target_groups" {
  type = list(any)
}

variable "asg_cpu_max_threshold" {
  type = string
}
variable "asg_cpu_min_threshold" {
  type = string
}

variable "default_tags" {
  type = map(any)
}
variable "outline_container_image_uri" {
  type = string
}
variable "outline_registry_domain" {
  type = string
}
variable "port" {
  type = number
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