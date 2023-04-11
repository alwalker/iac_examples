output "cicd_bucket_name" {
  value = aws_s3_bucket.main.id
}

output "packer_iam_profile" {
  value = aws_iam_role.packer.name
}

output "outline_ecr_uri" {
  value = aws_ecr_repository.outline.repository_url
}
output "cicd_containers_username" {
  value = aws_iam_user.cicd_containers.name
}