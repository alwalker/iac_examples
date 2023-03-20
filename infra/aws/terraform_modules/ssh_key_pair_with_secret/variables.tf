variable "name" {
  type = string
}

variable "recovery_window_days" {
  type = number
  default = 0
}

variable "tags" {
  type = map
}