resource "aws_ecr_repository" "outline" {
  name = "outline"

  force_delete = true
}

resource "aws_iam_user" "cicd_containers" {
  name = "cicd-containers"
}
resource "aws_iam_access_key" "cicd_containers" {
  user = aws_iam_user.cicd_containers.name
}
data "aws_iam_policy_document" "cicd_containers" {
  statement {
    effect    = "Allow"
    actions   = ["ecr:*"]
    resources = [aws_ecr_repository.outline.arn]
  }
  statement {
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = [
      "*"
    ]
  }
}
resource "aws_iam_user_policy" "cicd_containers" {
  name   = "cicd-containers"
  user   = aws_iam_user.cicd_containers.name
  policy = data.aws_iam_policy_document.cicd_containers.json
}
data "aws_iam_policy" "task_execution" {
  name = "AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_user_policy_attachment" "task_execution" {
  user       = aws_iam_user.cicd_containers.name
  policy_arn = data.aws_iam_policy.task_execution.arn
}

resource "github_actions_secret" "aws_access_key" {
  repository      = "iac_examples"
  secret_name     = "AWS_ACCESS_KEY_ID"
  plaintext_value = aws_iam_access_key.cicd_containers.id
}
resource "github_actions_secret" "aws_secret_access_key" {
  repository      = "iac_examples"
  secret_name     = "AWS_SECRET_ACCESS_KEY"
  plaintext_value = aws_iam_access_key.cicd_containers.secret
}

data "template_file" "push_to_ecr_workflow" {
  template = file("${path.module}/push_outline_to_ecr.tftpl")

  vars = {
    ecr_repo     = aws_ecr_repository.outline.repository_url
    ecr_registry = split("/", aws_ecr_repository.outline.repository_url)[0]
  }
}
resource "local_file" "push_to_ecr_workflow" {
  filename = "${path.module}/../../../.github/workflows/push_outline_to_ecr.yaml"
  content  = data.template_file.push_to_ecr_workflow.rendered
}