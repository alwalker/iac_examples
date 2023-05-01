variable "name" {
  type = string
}
variable "availability_zone" {
  type = string
}
variable "cidr_block" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "route_table_id" {
  type = string
}

variable "default_tags" {
  type = map(any)
}