output "alb_endpoint" {
  value = module.alb_endpoint
}
output "database" {
  sensitive = true
  value     = module.database
}
output "security" {
  sensitive = true
  value     = module.security
}
output "ecs" {
  value = module.ecs
}
