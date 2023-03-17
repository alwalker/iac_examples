resource "tls_private_key" "main" {
  algorithm = "ED25519"
}

resource "aws_secretsmanager_secret" "main" {
  name                           = "${var.name}-openssh-private-key"
  force_overwrite_replica_secret = true
  recovery_window_in_days        = var.recovery_window_days

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "main" {
  secret_id     = aws_secretsmanager_secret.main.id
  secret_string = tls_private_key.main.private_key_openssh
}

resource "aws_key_pair" "main" {
  key_name   = var.name
  public_key = trimspace(tls_private_key.main.public_key_openssh)

  tags = var.tags
}