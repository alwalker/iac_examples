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