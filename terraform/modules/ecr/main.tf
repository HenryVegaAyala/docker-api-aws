variable "project_name" { type = string }
variable "environment" {
  type        = string
  description = "Entorno (dev, uat, prod)"
}

data "aws_caller_identity" "current" {}

resource "aws_ecr_repository" "repo" {
  name                 = "${var.project_name}-${var.environment}-api"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecr"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "Application"
  }
}

resource "aws_ecr_lifecycle_policy" "lifecycle_policy" {
  repository = aws_ecr_repository.repo.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Eliminar imágenes sin etiquetar después de 1 día"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 10
        description  = "Mantener solo las últimas 10 imágenes"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = { type = "expire" }
      }
    ]
  })
}

resource "aws_ecr_repository_policy" "ecr_repository_policy" {
  repository = aws_ecr_repository.repo.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "LimitedAccess"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      }
      Action = [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ]
    }]
  })
}

output "repository_url" { value = aws_ecr_repository.repo.repository_url }
