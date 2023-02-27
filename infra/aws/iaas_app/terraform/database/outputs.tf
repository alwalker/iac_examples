output "name" {
  value = var.name
}
output "username" {
    value = var.name
}
output "password" {
    value = random_password.main.result
}