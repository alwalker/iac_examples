resource "aws_cloudwatch_log_group" "main" {
  name              = "${var.env_name}-${var.name}"
  retention_in_days = "30"

  tags = var.default_tags
}

data "template_file" "cloudwatch_config" {
  template = file("${path.module}/cloudwatch_config.tftpl")

  vars = {
    log_group_name    = aws_cloudwatch_log_group.main.name
    metrics_namespace = "${var.env_name}-${var.name}"
  }
}
resource "aws_s3_object" "cloudwatch_config" {
  bucket                 = var.bucket_name
  key                    = "cloudwatch-prod.json"
  acl                    = "private"
  bucket_key_enabled     = true
  server_side_encryption = "aws:kms"
  content                = data.template_file.cloudwatch_config.rendered
}
