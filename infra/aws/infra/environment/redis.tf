resource "aws_security_group" "redis" {
  name        = "${var.env_name}-redis"
  vpc_id      = module.vpc.vpc_id
  description = "Allow Redis in"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.outline.id]
  }
  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  tags = var.default_tags
}

resource "aws_elasticache_cluster" "main" {
  cluster_id           = "${var.env_name}-redis"
  engine               = "redis"
  engine_version       = "7.0"
  node_type            = var.redis_instance_size
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  security_group_ids   = [aws_security_group.redis.id]
  subnet_group_name    = module.vpc.elasticache_subnet_group_name
  port                 = 6379
}
