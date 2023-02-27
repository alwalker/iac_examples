terraform {
  required_providers {
    postgresql = {
      source = "cyrilgdn/postgresql"
    }
  }
}

resource "random_password" "main" {
  length           = 32
  override_special = "!@%*()-_=+[]{}:?"
}
resource "aws_secretsmanager_secret" "password" {
  name                           = "database-${var.name}-password"
  force_overwrite_replica_secret = true
  recovery_window_in_days        = 0

  tags = var.default_tags
}
resource "aws_secretsmanager_secret_version" "password" {
  secret_id     = aws_secretsmanager_secret.password.id
  secret_string = random_password.main.result
}

resource "postgresql_role" "main" {
  name                      = var.name
  superuser                 = false
  create_database           = false
  inherit                   = true
  login                     = true
  replication               = false
  bypass_row_level_security = false
  connection_limit          = -1
  encrypted_password        = true
  password                  = random_password.main.result
}

resource "postgresql_database" "main" {
  depends_on = [
    postgresql_role.main
  ]
  lifecycle {
    ignore_changes = [
      encoding,
      lc_collate,
      lc_ctype
    ]
  }

  name              = var.name
  owner             = var.name
  connection_limit  = -1
  allow_connections = true
  is_template       = false
  encoding          = "DEFAULT"
  lc_collate        = "DEFAULT"
  lc_ctype          = "DEFAULT"
}
