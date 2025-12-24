# ==============================================================================
# VARIABLES
# ==============================================================================

variable "domain_name" {
  description = "Nombre del dominio principal para el certificado SSL"
  type        = string
}

variable "subject_alternative_names" {
  description = "Lista de nombres alternativos del sujeto (SANs) para el certificado"
  type        = list(string)
  default     = []
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Entorno (dev, uat, prod)"
  type        = string
}

variable "zone_id" {
  description = "ID de la zona Route53 para validación DNS"
  type        = string
}

variable "tags" {
  description = "Tags adicionales para el certificado"
  type        = map(string)
  default     = {}
}

# ==============================================================================
# ACM CERTIFICATE
# ==============================================================================

resource "aws_acm_certificate" "this" {
  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names
  validation_method         = "DNS"

  tags = merge(
    {
      Name        = "${var.project_name}-${var.environment}-cert"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = "Application"
    },
    var.tags
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ==============================================================================
# DNS VALIDATION RECORDS
# ==============================================================================

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.zone_id
}

# ==============================================================================
# CERTIFICATE VALIDATION
# ==============================================================================

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]

  timeouts {
    create = "10m"
  }
}

# ==============================================================================
# OUTPUTS
# ==============================================================================

output "certificate_arn" {
  description = "ARN del certificado ACM"
  value       = aws_acm_certificate.this.arn
}

output "certificate_domain_name" {
  description = "Nombre del dominio del certificado"
  value       = aws_acm_certificate.this.domain_name
}

output "certificate_status" {
  description = "Estado del certificado"
  value       = aws_acm_certificate.this.status
}

output "certificate_validation_arn" {
  description = "ARN del certificado validado"
  value       = aws_acm_certificate_validation.this.certificate_arn
}

