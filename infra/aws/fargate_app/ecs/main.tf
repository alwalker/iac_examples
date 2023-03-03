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
    { name = "URL", value = "${var.outline_url}" },
    { name = "PORT", value = tostring(var.app_port) },
    { name = "FORCE_HTTPS", value = "false" },
    { name = "AWS_S3_UPLOAD_BUCKET_NAME", value = var.bucket_name },
    { name = "OIDC_CLIENT_ID", value = var.oidc_client_id },
    { name = "OIDC_CLIENT_SECRET", value = var.oidc_client_secret },
    { name = "OIDC_AUTH_URI", value = var.oidc_auth_url },
    { name = "OIDC_TOKEN_URI", value = var.oidc_token_uri },
    { name = "OIDC_USERINFO_URI", value = var.oidc_userinfo_uri },
    { name = "OIDC_USERNAME_CLAIM", value = "email" }
  ]
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
      name       = var.name
      image      = var.outline_container_image_uri
      entryPoint = ["/bin/sh", "-c"]
      command    = ["yarn db:migrate && yarn start"]
      cpu        = 1024
      memory     = 2048
      essential  = true
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

  tags = var.default_tags
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

resource "aws_ecs_task_definition" "scheduled_jobs" {
  family                   = "${var.name}-scheduled-jobs"
  cpu                      = 256
  memory                   = 512
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = var.execution_role_arn

  container_definitions = jsonencode([
    {
      name        = var.name
      image       = "docker.io/library/alpine"
      entryPoint  = ["/bin/sh", "-c"]
      command     = ["apk add curl && curl ${var.outline_url}/api/cron.daily?token=$UTILS_SECRET"]
      cpu         = 256
      memory      = 512
      essential   = true
      environment = local.env_vars
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.cloudwatch_group_name
          awslogs-region        = var.log_region
          awslogs-stream-prefix = "daily-job"
        }
      }
    }
  ])

  tags = var.default_tags
}

data "aws_iam_policy_document" "event_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}
resource "aws_iam_role" "ecs_events" {
  name               = "ecs_events"
  assume_role_policy = data.aws_iam_policy_document.event_assume_role.json

  tags = var.default_tags
}

data "aws_iam_policy_document" "ecs_events_run_task_with_any_role" {
  statement {
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["ecs:RunTask"]
    resources = [replace(aws_ecs_task_definition.scheduled_jobs.arn, "/:\\d+$/", ":*")]
  }
}
resource "aws_iam_role_policy" "ecs_events_run_task_with_any_role" {
  name   = "ecs_events_run_task_with_any_role"
  role   = aws_iam_role.ecs_events.id
  policy = data.aws_iam_policy_document.ecs_events_run_task_with_any_role.json
}

resource "aws_cloudwatch_event_rule" "scheduled_jobs" {
  name                = "${var.name}-scheduled-jobs"
  schedule_expression = "rate(1 day)"

  tags = var.default_tags
}
resource "aws_cloudwatch_event_target" "ecs_scheduled_task" {
  target_id = "${var.name}-scheduled-jobs"
  arn       = var.cluster_arn
  rule      = aws_cloudwatch_event_rule.scheduled_jobs.name
  role_arn  = aws_iam_role.ecs_events.arn

  ecs_target {
    task_count          = 1
    task_definition_arn = aws_ecs_task_definition.scheduled_jobs.arn

    network_configuration {
      subnets          = var.subnets
      security_groups  = var.security_groups
      assign_public_ip = false
    }
  }
}
