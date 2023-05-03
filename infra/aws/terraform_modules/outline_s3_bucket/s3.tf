resource "aws_s3_bucket" "main" {
  bucket = "awsiac-${var.env_name}-outline"

  tags = var.default_tags
}
resource "aws_s3_bucket_ownership_controls" "main" {
  bucket = aws_s3_bucket.main.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}
resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
resource "aws_s3_bucket_acl" "main" {
  depends_on = [
    aws_s3_bucket_ownership_controls.main,
    aws_s3_bucket_public_access_block.main
  ]

  bucket = aws_s3_bucket.main.id
  acl    = "public-read"
}
resource "aws_s3_bucket_cors_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  cors_rule {
    allowed_headers = [
      "*"
    ]
    allowed_methods = [
      "PUT",
      "POST"
    ]
    allowed_origins = [
      var.base_url
    ]
  }

  cors_rule {
    allowed_methods = [
      "GET"
    ]
    allowed_origins = [
      "*"
    ]
  }
}

resource "aws_s3_bucket" "logs" {
  bucket = "awsiac-${var.env_name}-outline-logs"
}
resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}
resource "aws_s3_bucket_acl" "logs" {
  depends_on = [
    aws_s3_bucket_ownership_controls.logs
  ]

  bucket = aws_s3_bucket.logs.id
  acl    = "log-delivery-write"
}
resource "aws_s3_bucket_logging" "main" {
  depends_on = [
    aws_s3_bucket_acl.logs,
    aws_s3_bucket_acl.main
  ]

  bucket = aws_s3_bucket.main.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "log/"
}
