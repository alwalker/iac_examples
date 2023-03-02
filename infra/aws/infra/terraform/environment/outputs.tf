output "vpc" {
  value = module.vpc
}
output "dns_zone" {
  value = aws_route53_zone.main
}

output "database" {
  value = aws_db_instance.main
}
output "database_admin_username" {
  value = var.database_admin_username
}
output "database_admin_password" {
  value = random_password.database_admin_password.result
}

output "bastion_ssh_private_key" {
  value = tls_private_key.bastion_ssh_key.private_key_openssh
}
output "bastion_ssh_public_key" {
  value = tls_private_key.bastion_ssh_key.public_key_openssh
}
output "bastion" {
  value = aws_instance.bastion
}
output "bastion_dns_name" {
  value = aws_route53_record.bastion.name
}

output "outline_security_group_id" {
  value = aws_security_group.outline.id
}

output "alb" {
  value = aws_lb.main
}
output "alb_https_listener" {
  value = aws_lb_listener.https
}
output "alb_security_group_id" {
  value = aws_security_group.alb.id
}
output "acm_cert_arn" {
  value = aws_acm_certificate.main.arn
}

output "redis" {
  value = aws_elasticache_cluster.main
}

output "ecs_cluster" {
  value = aws_ecs_cluster.main
}