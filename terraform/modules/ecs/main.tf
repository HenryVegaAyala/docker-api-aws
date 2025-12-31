# ==============================================================================
# VARIABLES
# ==============================================================================

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "Entorno (dev, uat, prod)"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC"
  type        = string
}

variable "public_subnets" {
  description = "Lista de subnets públicas"
  type        = list(string)
}

variable "private_subnets" {
  description = "Lista de subnets privadas"
  type        = list(string)
}

variable "repository_url" {
  description = "URL del repositorio ECR"
  type        = string
}

variable "image_tag" {
  description = "Tag de la imagen Docker"
  type        = string
}

variable "cpu" {
  description = "CPU para la tarea ECS"
  type        = number
}

variable "memory" {
  description = "Memoria para la tarea ECS"
  type        = number
}

variable "desired_count" {
  description = "Número deseado de tareas"
  type        = number
}

variable "log_group_name" {
  description = "Nombre del grupo de logs de CloudWatch"
  type        = string
}

variable "task_role_arn" {
  description = "ARN del rol de la tarea"
  type        = string
}

variable "exec_role_arn" {
  description = "ARN del rol de ejecución"
  type        = string
}

variable "secret_arn" {
  description = "ARN del secreto en Secrets Manager"
  type        = string
}

variable "enable_alb" {
  description = "Habilita o deshabilita el uso de Application Load Balancer (ALB)"
  type        = bool
  default     = false
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks permitidos para acceder a la aplicación (solo cuando ALB está deshabilitado)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "certificate_arn" {
  description = "ARN del certificado SSL de ACM para HTTPS"
  type        = string
  default     = ""
}

variable "enable_ssl" {
  description = "Habilitar SSL/TLS con certificado ACM"
  type        = bool
  default     = false
}


variable "enable_nat" {
  description = "Indica si NAT Gateway está habilitado en la VPC"
  type        = bool
  default     = false
}

# ==============================================================================
# LOCALS
# ==============================================================================

locals {
  container_name = "${var.project_name}-${var.environment}-api"
  image          = "${var.repository_url}:${var.image_tag}"
}

data "aws_region" "current" {}
resource "aws_ecs_cluster" "this" {
  name = "${var.project_name}-${var.environment}-cluster"
  tags = {
    Name        = "${var.project_name}-${var.environment}-cluster"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "Application"
  }
}

# SG del ALB
resource "aws_security_group" "alb" {
  name   = "${var.project_name}-${var.environment}-alb-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP traffic"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-alb-sg"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "Application"
  }
}

# SG de ECS - Tráfico restrictivo
resource "aws_security_group" "ecs" {
  name        = "${var.project_name}-${var.environment}-ecs-sg"
  description = "Security group for ECS tasks with restricted access"
  vpc_id      = var.vpc_id

  # Permitir tráfico desde ALB cuando está habilitado
  dynamic "ingress" {
    for_each = var.enable_alb ? [1] : []
    content {
      from_port       = 3000
      to_port         = 3000
      protocol        = "tcp"
      security_groups = [aws_security_group.alb.id]
      description     = "Allow traffic from ALB"
    }
  }

  # Permitir tráfico desde IPs específicas cuando ALB está deshabilitado
  dynamic "ingress" {
    for_each = var.enable_alb ? [] : [1]
    content {
      from_port   = 3000
      to_port     = 3000
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidr_blocks
      description = "Allow traffic from specific IPs"
    }
  }

  # Egress restrictivo - solo HTTPS para APIs externas
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS outbound"
  }

  # Egress para MongoDB Atlas (puerto 27017)
  egress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow MongoDB Atlas connection"
  }

  # Egress para Redis (puerto 6379) - permite conexión a cualquier Redis en la VPC
  egress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow Redis connection"
  }

  # Egress para PostgreSQL/RDS (puerto 5432)
  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow PostgreSQL/RDS connection"
  }

  # Egress para servicios AWS (ECR, Secrets Manager, etc)
  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    prefix_list_ids = [data.aws_prefix_list.s3.id]
    description     = "Allow access to AWS services"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-sg"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "Application"
  }
}


# Data source para obtener prefix list de S3
data "aws_prefix_list" "s3" {
  filter {
    name   = "prefix-list-name"
    values = ["com.amazonaws.${data.aws_region.current.id}.s3"]
  }
}

resource "aws_lb" "this" {
  count              = var.enable_alb ? 1 : 0
  name               = "${var.project_name}-${var.environment}-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnets

  tags = {
    Name        = "${var.project_name}-${var.environment}-alb"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "Application"
  }
}

resource "aws_lb_target_group" "this" {
  count       = var.enable_alb ? 1 : 0
  name        = "${var.project_name}-${var.environment}-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 10
    interval            = 30
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name        = "${var.project_name}-${var.environment}-tg"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "Application"
  }
}

resource "aws_lb_listener" "http" {
  count             = var.enable_alb ? 1 : 0
  load_balancer_arn = aws_lb.this[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = var.enable_ssl ? "redirect" : "forward"

    # Si hay certificado, redirigir HTTP a HTTPS
    dynamic "redirect" {
      for_each = var.enable_ssl ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    # Si no hay certificado, forward directo
    target_group_arn = var.enable_ssl ? null : aws_lb_target_group.this[0].arn
  }
}

# Listener HTTPS (solo si hay certificado)
resource "aws_lb_listener" "https" {
  count             = var.enable_alb && var.enable_ssl ? 1 : 0
  load_balancer_arn = aws_lb.this[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[0].arn
  }
}

resource "aws_ecs_task_definition" "task" {
  family                   = "${var.project_name}-${var.environment}-task"
  cpu                      = var.cpu
  memory                   = var.memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  task_role_arn            = var.task_role_arn
  execution_role_arn       = var.exec_role_arn

  container_definitions = jsonencode([
    {
      name      = local.container_name
      image     = local.image
      essential = true

      # Seguridad mejorada
      readonlyRootFilesystem = false # FastAPI necesita escribir en /tmp para logs temporales
      privileged             = false
      # user                   = "appbk" # Usuario definido en Dockerfile (UID 1001)

      portMappings = [{ containerPort = 3000, hostPort = 3000, protocol = "tcp" }]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.log_group_name
          awslogs-region        = data.aws_region.current.id
          awslogs-stream-prefix = "ecs"
        }
      }

      secrets =  [
        {
          name = "DB_URL",
          valueFrom = "${var.secret_arn}:DB_URL::"
        },
        {
          name = "POSTGRES_USER",
          valueFrom = "${var.secret_arn}:POSTGRES_USER::"
        },
        {
          name = "POSTGRES_PASSWORD",
          valueFrom = "${var.secret_arn}:POSTGRES_PASSWORD::"
        },
        {
          name = "POSTGRES_DB",
          valueFrom = "${var.secret_arn}:POSTGRES_DB::"
        },
        {
          name = "POSTGRES_HOST",
          valueFrom = "${var.secret_arn}:POSTGRES_HOST::"
        },
        {
          name = "POSTGRES_PORT",
          valueFrom = "${var.secret_arn}:POSTGRES_PORT::"
        }
      ]

      environment = [
        { name = "PORT", value = "3000" },
        { name = "ENVIRONMENT", value = var.environment },
        { name = "HOST", value = "0.0.0.0" }
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"]
        interval    = 30
        timeout     = 10
        retries     = 3
        startPeriod = 15 # FastAPI inicia rápidamente
      }

      # Volúmenes temporales para escritura si se necesitan
      mountPoints = []
    }
  ])

  tags = {
    Name        = "${var.project_name}-${var.environment}-task"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "Application"
  }
}

resource "aws_ecs_service" "svc" {
  name            = "${var.project_name}-${var.environment}-svc"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    # Si enable_alb está activo Y hay NAT Gateway, usar subredes privadas
    # De lo contrario, usar subredes públicas para acceso a Internet
    subnets          = (var.enable_alb && var.enable_nat) ? var.private_subnets : var.public_subnets
    security_groups  = [aws_security_group.ecs.id]
    # Asignar IP pública solo si estamos en subredes públicas
    assign_public_ip = (var.enable_alb && var.enable_nat) ? false : true
  }

  dynamic "load_balancer" {
    for_each = var.enable_alb ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.this[0].arn
      container_name   = local.container_name
      container_port   = 3000
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-svc"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "Application"
  }
}

# ==============================================================================
# OUTPUTS
# ==============================================================================

output "alb_dns_name" {
  value       = var.enable_alb ? aws_lb.this[0].dns_name : null
  description = "DNS del ALB (solo si está habilitado)"
}

output "alb_arn" {
  value       = var.enable_alb ? aws_lb.this[0].arn : null
  description = "ARN del ALB"
}

output "alb_zone_id" {
  value       = var.enable_alb ? aws_lb.this[0].zone_id : null
  description = "Zone ID del ALB"
}

output "target_group_arn" {
  value       = var.enable_alb ? aws_lb_target_group.this[0].arn : null
  description = "ARN del Target Group"
}

output "cluster_name" {
  value       = aws_ecs_cluster.this.name
  description = "Nombre del cluster ECS"
}

output "service_name" {
  value       = aws_ecs_service.svc.name
  description = "Nombre del servicio ECS"
}

output "ecs_security_group_id" {
  value       = aws_security_group.ecs.id
  description = "ID del Security Group de ECS"
}

