output "cicd_bucket_name" {
  value = local.cicd_bucket_name
}

output "outline_ecr_uri" {
  value = aws_ecr_repository.outline.repository_url
}