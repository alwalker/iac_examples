variable "name" {
  type = string
}

variable "cognito_pool_id" {
  type = string
}

variable "callback_urls" {
  type = list(string)
}