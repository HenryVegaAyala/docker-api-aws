# ==============================================================================
# CONFIGURACIÓN GENERAL DEL PROYECTO
# ==============================================================================

variable "project_name" {
  type        = string
  default     = "app-aws"
  description = "Nombre del proyecto"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Ambiente de despliegue"
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "Región de AWS"
}

# ==============================================================================
# CONFIGURACIÓN DE RED (VPC)
# ==============================================================================

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "CIDR block para la VPC de dev"
}

variable "enable_nat" {
  type        = bool
  default     = false
  description = "Habilitar NAT Gateway"
}

# ==============================================================================
# CONFIGURACIÓN DE ECS
# ==============================================================================

variable "image_tag" {
  type        = string
  default     = "latest"
  description = "Tag de la imagen Docker"
}

variable "desired_count" {
  type        = number
  default     = 1
  description = "Número deseado de tareas ECS"
}

variable "enable_alb" {
  type        = bool
  default     = true
  description = "Habilitar Application Load Balancer"
}

# ==============================================================================
# CONFIGURACIÓN DE SSL/TLS Y DNS
# ==============================================================================

variable "enable_ssl" {
  type        = bool
  default     = true
  description = "Habilitar SSL/TLS con certificado ACM"
}

variable "domain_name" {
  type        = string
  description = "Dominio principal para el certificado SSL (ej: example.com)"
}

variable "subdomain" {
  type        = string
  default     = "api-dev"
  description = "Subdominio para este entorno (ej: api-dev, api-uat, api)"
}

# ==============================================================================
# CONFIGURACIÓN DE RDS
# ==============================================================================

variable "enabled_rds" {
  type        = bool
  default     = true
  description = "Habilitar RDS para la base de datos"
}

variable "db_username" {
  type        = string
  default     = "dbadmin"
  description = "Nombre de usuario para la base de datos RDS"
}

variable "db_password" {
  type        = string
  default     = "ChangeMe123!"
  description = "Nombre de usuario para la base de datos RDS"
}


variable "db_name" {
  type        = string
  default     = "appdb"
  description = "Nombre de usuario para la base de datos RDS"
}


# ==============================================================================
# MÓDULOS DE INFRAESTRUCTURA
# ==============================================================================

# Data Source - Obtener zona Route53 por dominio
data "aws_route53_zone" "selected" {
  count        = var.enable_ssl && var.domain_name != "" ? 1 : 0
  name         = var.domain_name
  private_zone = false
}

module "vpc" {
  source               = "../../modules/vpc"
  project_name         = var.project_name
  environment          = var.environment
  enable_nat           = var.enable_nat
  vpc_cidr             = var.vpc_cidr
  enable_flow_logs     = true # Habilitar monitoreo de seguridad
  enable_vpc_endpoints = true # Habilitar VPC Endpoints para servicios AWS
}

module "ecr" {
  source       = "../../modules/ecr"
  project_name = var.project_name
  environment  = var.environment
}

module "iam" {
  source       = "../../modules/iam"
  project_name = var.project_name
  environment  = var.environment
}

module "cloudwatch" {
  source                 = "../../modules/cloudwatch"
  project_name           = var.project_name
  environment            = var.environment
  retention_days         = 7 # Reducido de 14 a 7 días para dev
  ecs_execution_role_arn = module.iam.task_execution_role_arn
}

module "secrets" {
  source       = "../../modules/secrets"
  project_name = var.project_name
  environment  = var.environment
  rds_endpoint = var.enabled_rds ? module.rds[0].endpoint : ""
  db_username  = var.db_username
  db_password  = var.db_password
  db_name      = var.db_name
}

module "ecs" {
  source          = "../../modules/ecs"
  project_name    = var.project_name
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  public_subnets  = module.vpc.public_subnet_ids
  private_subnets = module.vpc.private_subnet_ids
  repository_url  = module.ecr.repository_url
  image_tag       = var.image_tag
  cpu             = 256
  memory          = 512
  desired_count   = var.desired_count
  log_group_name  = module.cloudwatch.log_group_name
  task_role_arn   = module.iam.task_role_arn
  exec_role_arn   = module.iam.task_execution_role_arn
  secret_arn      = module.secrets.secret_arn
  enable_alb      = var.enable_alb
  enable_ssl      = var.enable_ssl && var.domain_name != ""
  certificate_arn = var.enable_ssl && var.domain_name != "" ? data.aws_acm_certificate.api[0].arn : ""
  enable_nat      = var.enable_nat
}

# Módulo ACM - Certificado SSL
module "acm" {
  count                     = var.enable_ssl && var.domain_name != "" ? 1 : 0
  source                    = "../../modules/acm"
  project_name              = var.project_name
  environment               = var.environment
  domain_name               = var.subdomain != "" ? "${var.subdomain}.${var.domain_name}" : var.domain_name
  subject_alternative_names = []
  zone_id                   = data.aws_route53_zone.selected[0].zone_id
}

# Módulo Route53 - DNS
module "route53" {
  count        = var.enable_ssl && var.domain_name != "" && var.enable_alb ? 1 : 0
  source       = "../../modules/route53"
  project_name = var.project_name
  environment  = var.environment
  domain_name  = var.domain_name
  subdomain    = var.subdomain
  alb_dns_name = module.ecs.alb_dns_name
  alb_zone_id  = module.ecs.alb_zone_id
}

# Módulo RDS
module "rds" {
  count              = var.enabled_rds ? 1 : 0
  source             = "../../modules/rds"
  project_name       = var.project_name
  environment        = var.environment
  db_username        = var.db_username
  db_password        = var.db_password
  db_name            = var.db_name
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  ecs_security_group = module.ecs.ecs_security_group_id
  depends_on         = [module.ecs]
}