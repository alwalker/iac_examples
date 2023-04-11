variable "name" {
  type = string
}
variable "env_name" {
  type = string
}

variable "ami_name" {
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
variable "iam_profile_name" {
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
variable "availability_zones" {
  type = list(any)
}
variable "vpc_id" {
  type = string
}
variable "target_group_arns" {
  type = list(string)
}
variable "target_group_arn" {
  type = string
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





# variable "cw_kms_key_id" {
#   type = string
# }
