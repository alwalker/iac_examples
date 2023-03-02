variable "name" {
  type = string
}

variable "base_domain_name" {
  type = string
}
variable "certificate_arn" {
  type = string
}

variable "dns_zone_id" {
  type = string
}

variable "callback_urls" {
  type = list(string)
}
