# ==============================================================================
# VARIABLES
# ==============================================================================

variable "domain_name" {
  description = "Nombre del dominio principal"
  type        = string
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Entorno (dev, uat, prod)"
  type        = string
}

variable "alb_dns_name" {
  description = "DNS name del Application Load Balancer"
  type        = string
}

variable "alb_zone_id" {
  description = "Zone ID del Application Load Balancer"
  type        = string
}

variable "subdomain" {
  description = "Subdominio para el entorno (ej: api, api-dev, api-uat)"
  type        = string
  default     = ""
}


variable "tags" {
  description = "Tags adicionales"
  type        = map(string)
  default     = {}
}

# ==============================================================================
# DATA SOURCES
# ==============================================================================

# Buscar zona existente
data "aws_route53_zone" "existing" {
  name         = var.domain_name
  private_zone = false
}

# ==============================================================================
# LOCALS
# ==============================================================================

locals {
  zone_id = data.aws_route53_zone.existing.zone_id

  # Construir el FQDN basado en si hay subdominio o no
  record_name = var.subdomain != "" ? "${var.subdomain}.${var.domain_name}" : var.domain_name
}

# ==============================================================================
# A RECORD - ALB
# ==============================================================================

resource "aws_route53_record" "alb" {
  zone_id = local.zone_id
  name    = local.record_name
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# ==============================================================================
# HEALTH CHECK (OPCIONAL)
# ==============================================================================

resource "aws_route53_health_check" "alb" {
  fqdn              = local.record_name
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 30

  tags = merge(
    {
      Name        = "${var.project_name}-${var.environment}-health-check"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = "Application"
    },
    var.tags
  )
}

# ==============================================================================
# OUTPUTS
# ==============================================================================

output "zone_id" {
  description = "ID de la zona Route53"
  value       = local.zone_id
}

output "zone_name_servers" {
  description = "Name servers de la zona existente"
  value       = data.aws_route53_zone.existing.name_servers
}

output "record_name" {
  description = "FQDN del registro A creado"
  value       = aws_route53_record.alb.fqdn
}

output "record_url" {
  description = "URL completa del endpoint"
  value       = "https://${aws_route53_record.alb.fqdn}"
}

output "health_check_id" {
  description = "ID del health check de Route53"
  value       = aws_route53_health_check.alb.id
}

