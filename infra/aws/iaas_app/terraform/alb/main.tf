resource "aws_lb_target_group" "main" {
  name                 = var.name
  port                 = var.port
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "instance"
  deregistration_delay = 30

  health_check {
    healthy_threshold   = "2"
    unhealthy_threshold = "3"
    timeout             = "10"
    path                = "/"
    interval            = "30"
  }

  tags = var.default_tags
}

resource "aws_lb_listener_rule" "main" {
  listener_arn = var.listener_arn
  priority     = var.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  condition {
    host_header {
      values = var.host_headers
    }
  }
}

resource "aws_route53_record" "api" {
  zone_id = var.hostedzone_id
  name    = var.dns_name
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_dns_zone
    evaluate_target_health = false
  }
}