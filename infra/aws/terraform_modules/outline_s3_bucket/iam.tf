resource "aws_iam_policy" "main" {
  name = "${var.env_name}-outline"
  path = "/"

  policy = <<-EOJ
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "VisualEditor",
                "Effect": "Allow",
                "Action": [
                    "s3:GetObjectAcl",
                    "s3:DeleteObject",
                    "s3:PutObject",
                    "s3:GetObject",
                    "s3:PutObjectAcl"
                ],
                "Resource": "arn:aws:s3:::${aws_s3_bucket.main.id}/*"
            }
        ]
    }
    EOJ
}