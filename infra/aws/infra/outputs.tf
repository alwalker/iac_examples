output "prod" {
  sensitive = true
  value     = module.prod
}
output "domain_name" {
  value = local.domain_name
}