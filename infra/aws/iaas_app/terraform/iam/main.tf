resource "aws_iam_role" "main" {
  name        = var.name
  description = "Allows EC2 tasks to do the things"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  tags = var.default_tags
}

data "template_file" "policies" {
  template = file("${path.module}/policy.json")

  vars = {
    bucket_name = var.cicd_bucket_name
  }
}

resource "aws_iam_policy" "main" {
  name        = var.name
  description = "Grant api permisions to do the things"
  policy      = data.template_file.policies.rendered
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
  name = var.name
  role = aws_iam_role.main.id
}