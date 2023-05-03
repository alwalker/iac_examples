variable "name" {
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
variable "outline_bucket_policy_arn" {
  type = string
}

variable "default_tags" {
  type = map(any)
}