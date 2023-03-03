output "cicd_bucket_name" {
  value = local.cicd_bucket_name
}

output "outline_ecr_uri" {
  value = aws_ecr_repository.outline.repository_url
}
output "cicd_containers_user_arn" {
  value = aws_iam_user.cicd_containers.arn
}