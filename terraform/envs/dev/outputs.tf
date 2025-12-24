output "repository_url" {
  value       = module.ecr.repository_url
  description = "URL del repositorio ECR"
}

output "alb_dns_name" {
  value       = module.ecs.alb_dns_name
  description = "DNS del Application Load Balancer (si está habilitado)"
}

output "cluster_name" {
  value       = module.ecs.cluster_name
  description = "Nombre del cluster ECS"
}

output "service_name" {
  value       = module.ecs.service_name
  description = "Nombre del servicio ECS"
}

output "certificate_arn" {
  value       = var.enable_ssl && var.domain_name != "" ? module.acm[0].certificate_arn : null
  description = "ARN del certificado SSL (si está habilitado)"
}

output "domain_url" {
  value       = var.enable_ssl && var.domain_name != "" && var.enable_alb ? module.route53[0].record_url : null
  description = "URL completa del dominio con HTTPS"
}

output "route53_zone_id" {
  value       = var.enable_ssl && var.domain_name != "" && var.enable_alb ? module.route53[0].zone_id : null
  description = "ID de la zona Route53"
}

output "route53_name_servers" {
  value       = var.enable_ssl && var.domain_name != "" && var.enable_alb ? module.route53[0].zone_name_servers : []
  description = "Name servers de la zona Route53 existente"
}

