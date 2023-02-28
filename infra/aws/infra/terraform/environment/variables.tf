variable "env_name" {
  type = string
}
variable "centos_stream_version" {
  type    = string
  default = 9
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
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
variable "vpc_private_subnets" {
  type    = list(string)
  default = []
}
variable "vpc_database_subnets" {
  type    = list(string)
  default = []
}
variable "vpc_public_subnets" {
  type    = list(string)
  default = []
}
variable "vpc_elasticache_subnets" {
  type    = list(string)
  default = []
}
variable "vpc_private_subnet_offset" {
  type    = number
  default = 0
}
variable "vpc_database_subnet_offset" {
  type    = number
  default = 50
}
variable "vpc_public_subnet_offset" {
  type    = number
  default = 100
}
variable "vpc_elasticache_subnet_offset" {
  type    = number
  default = 110
}
variable "domain_name" {
  type = string
}


variable "database_storage_size_gb" {
  type    = number
  default = 100
}
variable "database_instance_size" {
  type    = string
  default = "db.t3.micro"
}
variable "database_backup_retention_period_days" {
  type    = number
  default = 7
}
variable "database_postgres_version" {
  type    = string
  default = "14"
}
variable "database_admin_username" {
  type = string
}

variable "redis_instance_size" {
  type    = string
  default = "cache.t4g.micro"
}

variable "ssh_port" {
  type    = string
  default = "22"
}
variable "app_port" {
  type = string
}

variable "cert_arn" {
  type    = string
  default = ""
}

variable "default_tags" {
  type = map(any)
}