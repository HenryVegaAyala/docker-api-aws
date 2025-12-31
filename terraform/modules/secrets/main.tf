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

variable "db_username" { type = string }
variable "db_password" { type = string }
variable "db_name" { type = string }
variable "rds_endpoint" { type = string }

locals {
  db_host = var.rds_endpoint != "" ? split(":", var.rds_endpoint)[0] : ""
  db_port = var.rds_endpoint != "" ? (length(split(":", var.rds_endpoint)) > 1 ? split(":", var.rds_endpoint)[1] : "5432") : "5432"
  db_url  = "postgresql://${var.db_username}:${var.db_password}@${local.db_host}:${local.db_port}/${var.db_name}"
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

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id

  secret_string = jsonencode({
    DB_URL            = local.db_url
    POSTGRES_USER     = var.db_username
    POSTGRES_PASSWORD = var.db_password
    POSTGRES_DB       = var.db_name
    POSTGRES_HOST     = local.db_host
    POSTGRES_PORT     = local.db_port
  })
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
