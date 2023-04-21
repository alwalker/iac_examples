output "vpc" {
  value = module.vpc
}
output "dns_zone" {
  value = aws_route53_zone.main
}
output "private_subnets_cidr" {
  value = local.private_subnets
}
output "dabatase_subnets_cidr" {
  value = local.dabatase_subnets
}
output "public_subnets_cidr" {
  value = local.public_subnets
}
output "elasticache_subnets_cidr" {
  value = local.elasticache_subnets
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
  value = module.bastion_ssh_key.key.private_key_openssh
}
output "bastion_ssh_public_key" {
  value = module.bastion_ssh_key.key.public_key_openssh
}
output "bastion" {
  value = aws_instance.bastion
}
output "bastion_dns_name" {
  value = aws_route53_record.bastion.name
}
output "bastion_security_group_id" {
  value = aws_security_group.bastion.id
}

output "outline_security_group_id" {
  value = aws_security_group.outline.id
}

output "alb" {
  value = var.enable_eks ? null : aws_lb.main[0]
}
output "alb_https_listener" {
  value = var.enable_eks ? null : aws_lb_listener.https[0]
}
output "alb_security_group" {
  value = var.enable_eks ? null : aws_security_group.alb[0]
}

output "acm_cert_arn" {
  value = aws_acm_certificate.main.arn
}

output "cognito" {
  value = module.cognito
}

output "redis" {
  value = aws_elasticache_cluster.main
}

output "ecs_cluster" {
  value = aws_ecs_cluster.main
}
