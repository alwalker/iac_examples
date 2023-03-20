module "cognito" {
  source = "../../../terraform_modules/cognito"

  name = "outline"

  certificate_arn  = aws_acm_certificate.main.arn
  base_domain_name = var.domain_name

  dns_zone_id = aws_route53_zone.main.id
}