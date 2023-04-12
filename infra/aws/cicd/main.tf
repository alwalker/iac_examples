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
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "github" {}

resource "aws_kms_key" "bucket_key" {
  deletion_window_in_days = 10
}
resource "aws_s3_bucket" "main" {
  bucket = "iac-examples-cicd"
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

data "archive_file" "source" {
  type        = "zip"
  output_path = "source.zip"
  source_dir  = "../../../src"
  excludes = [
    ".git",
    ".gitignore",
    ".circleci",
    ".vscode",
    ".dockerignore"
  ]
}
resource "aws_s3_object" "env_file" {
  bucket                 = aws_s3_bucket.main.id
  key                    = "source.zip"
  acl                    = "private"
  bucket_key_enabled     = true
  server_side_encryption = "aws:kms"
  source                 = data.archive_file.source.output_path
}