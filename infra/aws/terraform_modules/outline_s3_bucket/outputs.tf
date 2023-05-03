output "bucket" {
  value = aws_s3_bucket.main
}
output "log_bucket" {
  value = aws_s3_bucket.logs
}

output "iam_policy" {
  value = aws_iam_policy.main
}