data "aws_region" "current" {}

# data "aws_ami" "packer_base_image" {
#   owners      = ["125523088429"]
#   most_recent = true

#   filter {
#     name   = "name"
#     values = ["CentOS Stream 9*"]
#   }
#   filter {
#     name   = "virtualization-type"
#     values = ["hvm"]
#   }
#   filter {
#     name   = "architecture"
#     values = ["x86_64"]
#   }
# }
module "base_ami" {
  source = "../../terraform_modules/centos_ami"

  region                = data.aws_region.current.name
  centos_version_number = 9
}

resource "random_id" "outline_secret_key" {
  byte_length = 32
}
resource "random_id" "outline_util_secret_key" {
  byte_length = 32
}
resource "aws_s3_object" "env_file" {
  bucket                 = data.terraform_remote_state.cicd.outputs.cicd_bucket_name
  key                    = "outline-prod-env"
  acl                    = "private"
  bucket_key_enabled     = true
  server_side_encryption = "aws:kms"

  content = <<-EOT
  NODE_ENV=production
  SECRET_KEY=${random_id.outline_secret_key.hex}
  UTILS_SECRET=${random_id.outline_util_secret_key.hex}
  DATABASE_URL=postgres://outline:${module.database.password}@${data.terraform_remote_state.infra.outputs.prod.database.address}:5432/outline
  DATABASE_CONNECTION_POOL_MIN=1
  DATABASE_CONNECTION_POOL_MAX=5
  REDIS_URL=redis://${data.terraform_remote_state.infra.outputs.prod.redis.cache_nodes[0].address}
  URL=${local.dns_name}
  PORT=${local.outline_port}
  FORCE_HTTPS=false
  AWS_S3_UPLOAD_BUCKET_NAME=${module.s3.bucket.id}
  AWS_S3_FORCE_PATH_STYLE=false
  AWS_S3_UPLOAD_BUCKET_URL=https://${module.s3.bucket.bucket_regional_domain_name}
  AWS_S3_UPLOAD_MAX_SIZE=262144000
  OIDC_CLIENT_ID=${module.cognito_client.self.id}
  OIDC_CLIENT_SECRET=${module.cognito_client.self.client_secret}
  OIDC_AUTH_URI=${data.terraform_remote_state.infra.outputs.prod.cognito.oauth_info["authorization_endpoint"]}
  OIDC_TOKEN_URI=${data.terraform_remote_state.infra.outputs.prod.cognito.oauth_info["token_endpoint"]}
  OIDC_USERINFO_URI=${data.terraform_remote_state.infra.outputs.prod.cognito.oauth_info["userinfo_endpoint"]}
  OIDC_USERNAME_CLAIM=email
  EOT
}

data "template_file" "packer_file" {
  template = file("${path.module}/packer/outline.pkr.hcl.tftpl")

  vars = {
    aws_region         = data.aws_region.current.name
    instance_size      = "t3a.medium"
    iam_packer_profile = data.terraform_remote_state.cicd.outputs.packer_iam_profile
    vpc_subnet_id      = data.terraform_remote_state.infra.outputs.prod.vpc.public_subnets[0]
    vpc_id             = data.terraform_remote_state.infra.outputs.prod.vpc.vpc_id
    source_ami_id      = module.base_ami.id
  }
}
resource "local_file" "packer_file" {
  depends_on = [
    aws_s3_object.env_file
  ]

  content  = data.template_file.packer_file.rendered
  filename = "${path.module}/packer/outline.pkr.hcl"
}
