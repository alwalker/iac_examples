resource "aws_security_group" "database" {
  name        = "${var.env_name}-database"
  vpc_id      = module.vpc.vpc_id
  description = "Allow Postgres in"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.outline.id]
  }
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  tags = var.default_tags
}

resource "random_password" "database_admin_password" {
  length           = 32
  override_special = "!%*()-_=+[]{}:?"
}
resource "aws_secretsmanager_secret" "database_admin_password" {
  name                           = "database-admin-password"
  force_overwrite_replica_secret = true
  recovery_window_in_days        = 0

  tags = var.default_tags
}
resource "aws_secretsmanager_secret_version" "database_admin_password" {
  secret_id     = aws_secretsmanager_secret.database_admin_password.id
  secret_string = random_password.database_admin_password.result
}

resource "aws_db_instance" "main" {
  lifecycle {
    ignore_changes = [
      latest_restorable_time
    ]
  }

  allocated_storage           = var.database_storage_size_gb
  allow_major_version_upgrade = false
  apply_immediately           = false
  auto_minor_version_upgrade  = true
  backup_retention_period     = var.database_backup_retention_period_days
  backup_window               = "05:00-06:00"
  db_subnet_group_name        = module.vpc.database_subnet_group
  delete_automated_backups    = false
  engine                      = "postgres"
  engine_version              = var.database_postgres_version
  identifier                  = var.env_name
  instance_class              = var.database_instance_size
  maintenance_window          = "Mon:06:01-Mon:10:00"
  password                    = random_password.database_admin_password.result
  publicly_accessible         = false
  skip_final_snapshot         = true
  storage_encrypted           = true
  storage_type                = "gp2"
  username                    = var.database_admin_username
  vpc_security_group_ids      = [aws_security_group.database.id]

  tags = var.default_tags
}