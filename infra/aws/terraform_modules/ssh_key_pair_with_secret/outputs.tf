output "key" {
  value = tls_private_key.main
}

output "secret" {
  value = aws_secretsmanager_secret.main
}

output "aws_key_pair" {
  value = aws_key_pair.main
}