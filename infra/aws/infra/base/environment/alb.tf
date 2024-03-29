resource "aws_acm_certificate" "main" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  tags = var.default_tags
}
resource "aws_route53_record" "dns_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main.zone_id
}
resource "aws_acm_certificate_validation" "main" {
  depends_on = [
    namecheap_domain_records.nameservers
  ]

  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.dns_validation : record.fqdn]
}

resource "aws_security_group" "alb" {
  count = var.enable_eks ? 0 : 1

  name        = "${var.env_name}-alb"
  vpc_id      = module.vpc.vpc_id
  description = "Allow HTTP and HTTPS in from the world"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.default_tags
}

resource "aws_lb" "main" {
  count = var.enable_eks ? 0 : 1

  name                       = var.env_name
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb[0].id]
  subnets                    = module.vpc.public_subnets
  enable_deletion_protection = false

  tags = var.default_tags
}

# resource "aws_lb_target_group" "eks" {
#   count = var.enable_eks ? 1 : 0

#   name     = "${var.env_name}-eks"
#   port     = 80
#   protocol = "TCP"
#   vpc_id   = module.vpc.vpc_id

#   tags = var.default_tags
# }
# resource "aws_lb_listener" "eks_https" {
#   count = var.enable_eks ? 1 : 0

#   load_balancer_arn = aws_lb.main.arn
#   port              = 443
#   protocol          = "HTTP"

#   default_action {
#     type = "forward"

#     forward {
#       target_group {
#         arn = aws_lb_target_group.eks[0].arn
#       }
#     }
#   }
# }
# resource "aws_lb_listener" "eks_http" {
#   count = var.enable_eks ? 1 : 0

#   load_balancer_arn = aws_lb.main.arn
#   port              = 80
#   protocol          = "HTTPS"
#   certificate_arn   = aws_acm_certificate.main.arn

#   default_action {
#     type = "forward"

#     forward {
#       target_group {
#         arn = aws_lb_target_group.eks[0].arn
#       }
#     }
#   }
# }

resource "aws_lb_listener" "https" {
  count = var.enable_eks ? 0 : 1

  load_balancer_arn = aws_lb.main[0].arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.main.arn
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "HEALTHY"
      status_code  = "200"
    }
  }
}

resource "aws_lb_listener" "http_redirect" {
  count = var.enable_eks ? 0 : 1

  load_balancer_arn = aws_lb.main[0].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
