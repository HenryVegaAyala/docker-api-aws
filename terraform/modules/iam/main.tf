variable "project_name" { type = string }
variable "environment" {
  type        = string
  description = "Entorno (dev, uat, prod)"
}

data "aws_iam_policy_document" "execution" {
  statement {
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]
    resources = ["*"]
    effect    = "Allow"
  }

  # Permisos para acceder a Secrets Manager durante el inicio del contenedor
  statement {
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = ["*"]
    effect    = "Allow"
  }

  # Permisos para KMS (si CloudWatch Logs está encriptado)
  statement {
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]
    resources = ["*"]
    effect    = "Allow"
  }
}

resource "aws_iam_role" "task_execution" {
  name = "${var.project_name}-${var.environment}-ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-exec-role"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "Application"
  }
}

resource "aws_iam_policy" "task_execution" {
  name   = "${var.project_name}-${var.environment}-ecs-execution"
  policy = data.aws_iam_policy_document.execution.json
  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-exec-policy"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "Application"
  }
}

resource "aws_iam_role_policy_attachment" "attach_exec" {
  role       = aws_iam_role.task_execution.name
  policy_arn = aws_iam_policy.task_execution.arn
}

data "aws_iam_policy_document" "task" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["*"]
    effect    = "Allow"
  }
}

resource "aws_iam_role" "task_role" {
  name = "${var.project_name}-${var.environment}-ecsTaskRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-task-role"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "Application"
  }
}

resource "aws_iam_policy" "task" {
  name   = "${var.project_name}-${var.environment}-ecs-task"
  policy = data.aws_iam_policy_document.task.json
  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-task-policy"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "Application"
  }
}

resource "aws_iam_role_policy_attachment" "attach_task" {
  role       = aws_iam_role.task_role.name
  policy_arn = aws_iam_policy.task.arn
}

output "task_execution_role_arn" { value = aws_iam_role.task_execution.arn }
output "task_role_arn" { value = aws_iam_role.task_role.arn }
