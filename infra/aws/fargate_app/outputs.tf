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
output "cognito" {
  sensitive = true
  value     = module.cognito
}
output "ecs" {
  value = module.ecs
}
