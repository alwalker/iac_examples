output "user_pool" {
  value = aws_cognito_user_pool.main
}
output "domain" {
  value = aws_cognito_user_pool_domain.main
}

output "client" {
  value = aws_cognito_user_pool_client.main
}