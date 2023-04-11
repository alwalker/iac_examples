variable "name" {
    type = string
}
variable "env_name" {
    type = string
}
variable "bucket_name" {
    type = string
}

variable "default_tags" {
  type = map(any)
}