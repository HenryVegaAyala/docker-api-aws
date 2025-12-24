# ==============================================================================
# CONFIGURACIÓN DEL MÓDULO
# ==============================================================================

variable "project_name" {
  type        = string
  description = "Nombre del proyecto"
}

variable "environment" {
  type        = string
  description = "Entorno (dev, uat, prod)"
}

# ==============================================================================
# AWS SECRETS MANAGER - SECRET PRINCIPAL
# ==============================================================================

resource "aws_secretsmanager_secret" "app" {
  name        = "${var.project_name}/${var.environment}/app-secrets"
  description = "Application secrets for Application ${var.environment} environment"
  recovery_window_in_days = 0

  tags = {
    Name        = "${var.project_name}-${var.environment}-secrets"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "Application"
  }
}

# ==============================================================================
# OUTPUTS
# ==============================================================================

output "secret_arn" {
  value       = aws_secretsmanager_secret.app.arn
  description = "ARN del secret en AWS Secrets Manager"
}

output "secret_name" {
  value       = aws_secretsmanager_secret.app.name
  description = "Nombre del secret en AWS Secrets Manager"
}
