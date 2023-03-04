resource "aws_ecs_task_definition" "database_migrations" {
  family                   = "${var.name}-migrations"
  cpu                      = 1024
  memory                   = 2048
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  task_role_arn            = var.iam_role_arn
  execution_role_arn       = var.execution_role_arn

  container_definitions = jsonencode([
    {
      name        = var.name
      image       = var.outline_container_image_uri
      command     = ["yarn", "db:migrate"]
      cpu         = 1024
      memory      = 2048
      essential   = true
      environment = local.env_vars
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.cloudwatch_group_name
          awslogs-region        = var.log_region
          awslogs-stream-prefix = "migrations"
        }
      }
    }
  ])

  tags = var.default_tags
}

data "aws_iam_policy_document" "cicd_execute_migrations_task" {
  statement {
    actions = [
      "ecs:RunTask"
    ]
    resources = [
      aws_ecs_task_definition.database_migrations.arn
    ]
  }
  statement {
    actions = [
      "iam:PassRole"
    ]
    resources = [
      var.execution_role_arn
    ]
  }
}
resource "aws_iam_user_policy" "database_migration_task_execution" {
  name   = "execute-database-migration-task"
  user   = var.cicd_username
  policy = data.aws_iam_policy_document.cicd_execute_migrations_task.json
}

data "template_file" "database_migrations" {
  template = file("${path.module}/run_db_migrations_workflow.tftpl")

  vars = {
    subnet_id                    = jsonencode(var.subnets)
    security_group_id            = jsonencode(var.security_groups)
    ecs_cluster_name             = var.cluster_arn
    ecs_task_family_and_revision = "${var.name}-migrations:${aws_ecs_task_definition.database_migrations.revision}"
  }
}
resource "local_file" "database_migrations" {
  filename = "${path.module}/../../../../.github/workflows/database_migrations.yaml"
  content  = data.template_file.database_migrations.rendered
}
