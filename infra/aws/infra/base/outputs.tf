output "prod" {
  sensitive = true
  value     = module.prod
}
output "eks" {
  sensitive = true
  value     = module.eks
}
output "prod_domain_name" {
  value = local.domain_name
}
output "prod_domain_ns_records" {
  value = module.prod.dns_zone.name_servers
}
