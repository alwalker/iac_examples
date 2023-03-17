variable "name" {
  type = string
}

variable "env_name" {
  type = string
}

variable "app_port" {
  type = number
}
variable "outline_security_group_id" {
  type = string
}
variable "alb_security_group_id" {
  type = string
}
variable "bastion_security_group_id" {
  type = string
}

variable "bucket_name" {
  type = string
}
variable "outline_ecr_arn" {
  type = string
}

variable "default_tags" {
  type = map(any)
}