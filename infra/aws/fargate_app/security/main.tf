resource "aws_security_group_rule" "allow_alb_in" {
  security_group_id = var.outline_security_group_id

  type                     = "ingress"
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  source_security_group_id = var.alb_security_group_id
}
resource "aws_security_group_rule" "allow_outbound" {
  security_group_id = var.outline_security_group_id

  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_iam_role" "task" {
  name        = var.name
  description = "Allows ECS tasks to do the things"

  assume_role_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "",
        "Effect": "Allow",
        "Principal": {
          "Service": "ecs-tasks.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }
  EOF

  tags = var.default_tags
}
data "template_file" "task_policies" {
  template = file("${path.module}/policy.json")

  vars = {
    bucket_name = var.bucket_name
  }
}
resource "aws_iam_policy" "task" {
  name        = var.name
  description = "Grant outline permisions to do the things"
  policy      = data.template_file.task_policies.rendered
}
resource "aws_iam_role_policy_attachment" "task" {
  role       = aws_iam_role.task.name
  policy_arn = aws_iam_policy.task.arn
}

resource "aws_iam_role" "task_execution" {
  name        = "${var.name}-task-execution"
  description = "Allows ECS tasks to do the things"

  assume_role_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "",
        "Effect": "Allow",
        "Principal": {
          "Service": "ecs-tasks.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }
  EOF

  tags = var.default_tags
}
data "aws_iam_policy" "task_execution" {
  name = "AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = data.aws_iam_policy.task_execution.arn
}
