variable "project_name" { type = string }
variable "environment" {
  type        = string
  description = "Entorno (dev, uat, prod)"
}
variable "retention_days" {
  type        = number
  default     = 14
  description = "Días de retención de logs"
}
variable "enable_encryption" {
  type        = bool
  default     = true
  description = "Habilitar encriptación de logs con KMS"
}
variable "ecs_execution_role_arn" {
  type        = string
  default     = ""
  description = "ARN del rol de ejecución de ECS para permisos KMS"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# KMS Key para encriptar logs
resource "aws_kms_key" "cloudwatch" {
  count               = var.enable_encryption ? 1 : 0
  description         = "KMS key for CloudWatch Logs encryption - ${var.project_name}-${var.environment}"
  enable_key_rotation = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.id}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/${var.project_name}-${var.environment}"
          }
        }
      },
      {
        Sid    = "Allow ECS Task Execution Role"
        Effect = "Allow"
        Principal = {
          AWS = var.ecs_execution_role_arn != "" ? var.ecs_execution_role_arn : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-cloudwatch-kms"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "Application"
  }
}

resource "aws_kms_alias" "cloudwatch" {
  count         = var.enable_encryption ? 1 : 0
  name          = "alias/${var.project_name}-${var.environment}-cloudwatch"
  target_key_id = aws_kms_key.cloudwatch[0].key_id
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}-${var.environment}"
  retention_in_days = var.retention_days
  kms_key_id        = var.enable_encryption ? aws_kms_key.cloudwatch[0].arn : null

  tags = {
    Name        = "${var.project_name}-${var.environment}-logs"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "Application"
  }
}

output "log_group_name" {
  value       = aws_cloudwatch_log_group.ecs.name
  description = "Nombre del log group"
}

output "kms_key_id" {
  value       = var.enable_encryption ? aws_kms_key.cloudwatch[0].id : null
  description = "ID de la KMS key para logs"
}
