resource "aws_security_group_rule" "allow_alb_in" {
  security_group_id = var.outline_security_group_id

  type                     = "ingress"
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  source_security_group_id = var.alb_security_group_id
}
resource "aws_security_group_rule" "allow_bastion_in" {
  security_group_id = var.outline_security_group_id

  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = var.bastion_security_group_id
}
resource "aws_security_group_rule" "allow_outbound" {
  security_group_id = var.outline_security_group_id

  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}
resource "aws_iam_role" "main" {
  name               = "${var.env_name}-${var.name}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "main" {
  statement {
    actions = [
      "s3:*"
    ]
    resources = [
      "arn:aws:s3:::${var.bucket_name}",
      "arn:aws:s3:::${var.bucket_name}/*"
    ]
  }
  statement {
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer"
    ]
    resources = [
      var.outline_ecr_arn
    ]
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
resource "aws_iam_policy" "main" {
  name        = "${var.env_name}-${var.name}"
  description = "Allow Outline to do the things in ${var.env_name}"
  policy      = data.aws_iam_policy_document.main.json
}


resource "aws_iam_role_policy_attachment" "main" {
  role       = aws_iam_role.main.name
  policy_arn = aws_iam_policy.main.arn
}
resource "aws_iam_role_policy_attachment" "cloudwatchagent" {
  role       = aws_iam_role.main.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "main" {
  name = "${var.env_name}-${var.name}"
  role = aws_iam_role.main.id
}
