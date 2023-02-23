resource "tls_private_key" "alb_cert_private_key" {
  count = var.cert_arn == "" ? 1 : 0

  algorithm = "RSA"
}
resource "tls_self_signed_cert" "alb_cert" {
  count = var.cert_arn == "" ? 1 : 0

  private_key_pem = tls_private_key.alb_cert_private_key[0].private_key_pem
  dns_names = [
    var.domain_name,
    "*.${var.domain_name}"
  ]

  subject {
    common_name  = var.domain_name
    organization = "ALW Examples, Inc"
  }

  validity_period_hours = 12

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}
resource "aws_acm_certificate" "alb_cert" {
  count = var.cert_arn == "" ? 1 : 0

  private_key      = tls_private_key.alb_cert_private_key[0].private_key_pem
  certificate_body = tls_self_signed_cert.alb_cert[0].cert_pem
}

resource "aws_security_group" "alb" {
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
  name                       = var.env_name
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = module.vpc.public_subnets
  enable_deletion_protection = false

  tags = var.default_tags
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.cert_arn == "" ? aws_acm_certificate.alb_cert[0].arn : var.cert_arn
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
  load_balancer_arn = aws_lb.main.arn
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