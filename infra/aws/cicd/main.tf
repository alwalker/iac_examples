terraform {
  backend "s3" {
    region         = "us-east-1"
    bucket         = "awsiac-devops"
    key            = "terraform-states/cicd"
    dynamodb_table = "terraform-states-cicd" #LockID
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

locals {
  cicd_bucket_name = "alwiac-cicd"
}

resource "aws_kms_key" "bucket_key" {
  deletion_window_in_days = 10
}
resource "aws_s3_bucket" "main" {
  bucket = local.cicd_bucket_name
}
resource "aws_s3_bucket_acl" "main" {
  bucket = aws_s3_bucket.main.id
  acl    = "private"
}
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.bucket_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# resource "aws_iam_user" "cicd_runner" {
#   name = "cicd"
#   path = "/"
# }
# resource "aws_iam_user_policy_attachment" "gitlab" {
#   user = aws_iam_user.gitlab.name
#   policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
# }

resource "aws_iam_role" "packer" {
  name        = "packer"
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
}
data "template_file" "packer-policies" {
  template = file("packer_policy.json")

  vars = {
    bucket_name = aws_s3_bucket.main.id
  }
}
resource "aws_iam_policy" "packer" {
  name        = "packer"
  description = "Grant Packer permisions to do the things"
  policy      = data.template_file.packer-policies.rendered
}
resource "aws_iam_role_policy_attachment" "packer" {
  role       = aws_iam_role.packer.name
  policy_arn = aws_iam_policy.packer.arn
}
resource "aws_iam_instance_profile" "packer" {
  name = "packer"
  role = aws_iam_role.packer.id
}

resource "aws_ecr_repository" "outline" {
  name = "outline"

  force_delete = true
}
