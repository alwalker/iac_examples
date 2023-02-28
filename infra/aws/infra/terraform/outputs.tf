output "prod" {
  sensitive = true
  value     = module.prod
}
output "prod_domain_name" {
  value = local.domain_name
}