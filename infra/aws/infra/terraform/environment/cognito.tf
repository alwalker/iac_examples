resource "null_resource" "wait_for_dns" {
  depends_on = [
    aws_route53_record.root
  ]

  provisioner "local-exec" {
    interpreter = ["/usr/bin/bash"]
    environment = {
      ROOT_RECORD = var.domain_name
    }
    command = "${path.module}/wait-for-dns.sh"
  }
}

module "cognito" {
  source = "../../../terraform_modules/cognito"
  depends_on = [
    null_resource.wait_for_dns
  ]

  name = "outline"

  certificate_arn  = aws_acm_certificate.main.arn
  base_domain_name = var.domain_name

  dns_zone_id = aws_route53_zone.main.id
}
