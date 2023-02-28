resource "random_id" "secret_key" {
  byte_length = 32
}
resource "random_id" "util_secret_key" {
  byte_length = 32
}
locals {
  env_vars = [
    { name = "NODE_ENV", value = "production" },
    { name = "SECRET_KEY", value = tostring(random_id.secret_key.hex) },
    { name = "UTILS_SECRET", value = tostring(random_id.util_secret_key.hex) },
    { name = "DATABASE_URL", value = "postgres://${var.database_username}:${var.database_password}@${var.database_host}:5432/outline" },
    { name = "DATABASE_CONNECTION_POOL_MIN", value = "1" },
    { name = "DATABASE_CONNECTION_POOL_MAX", value = "5" },
    { name = "REDIS_URL", value = "redis://${var.redis_host}" },
    { name = "URL", value = "https://outline.${var.outline_url}" },
    { name = "PORT", value = tostring(var.app_port) },
    { name = "FORCE_HTTPS", value = "false" },
    { name = "AWS_S3_UPLOAD_BUCKET_NAME", value = var.bucket_name }
  ]
}

resource "aws_ecs_task_definition" "migrations" {
  family                   = "${var.name}-migrations"
  cpu                      = 1024
  memory                   = 2048
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  task_role_arn            = var.iam_role_arn
  execution_role_arn       = var.execution_role_arn

  container_definitions = jsonencode([
    {
      name        = "${var.name}-migrations"
      image       = var.outline_container_image_uri
      command     = ["yarn", "db:migrate"]
      environment = local.env_vars
      essential = true
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.cloudwatch_group_name
          awslogs-region        = var.log_region
          awslogs-stream-prefix = "${var.name}-migrations"
        }
      }
    }
  ])
}
resource "aws_ecs_service" "migrations" {
  name = "${var.name}-migrations"

  cluster                            = var.cluster_arn
  enable_execute_command             = true
  force_new_deployment               = var.force_new_deployment
  launch_type                        = "FARGATE"
  propagate_tags                     = "SERVICE"
  task_definition                    = "${var.name}-migrations:${aws_ecs_task_definition.migrations.revision}"

  network_configuration {
    subnets          = var.subnets
    security_groups  = var.security_groups
    assign_public_ip = false
  }

  tags = var.default_tags
}

resource "aws_ecs_task_definition" "main" {
  family                   = var.name
  cpu                      = 1024
  memory                   = 2048
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  task_role_arn            = var.iam_role_arn
  execution_role_arn       = var.execution_role_arn

  container_definitions = jsonencode([
    {
      name      = var.name
      image     = var.outline_container_image_uri
      cpu       = 1024
      memory    = 2048
      essential = true
      portMappings = [
        {
          containerPort = var.app_port
          hostPort      = var.app_port
        }
      ]
      environment = local.env_vars
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.cloudwatch_group_name
          awslogs-region        = var.log_region
          awslogs-stream-prefix = var.name
        }
      }
    }
  ])
}
resource "aws_ecs_service" "main" {
  lifecycle {
    ignore_changes = [
      desired_count
    ]
  }

  name = var.name

  cluster                            = var.cluster_arn
  deployment_minimum_healthy_percent = 25
  desired_count                      = 2
  enable_execute_command             = true
  force_new_deployment               = var.force_new_deployment
  health_check_grace_period_seconds  = 60
  launch_type                        = "FARGATE"
  propagate_tags                     = "SERVICE"
  task_definition                    = "${var.name}:${aws_ecs_task_definition.main.revision}"

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = var.name
    container_port   = var.app_port
  }

  network_configuration {
    subnets          = var.subnets
    security_groups  = var.security_groups
    assign_public_ip = false
  }

  tags = var.default_tags
}


