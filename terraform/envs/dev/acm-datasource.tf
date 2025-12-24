# Data source para obtener el certificado ACM después de que esté validado
data "aws_acm_certificate" "api" {
  count  = var.enable_ssl && var.domain_name != "" ? 1 : 0
  domain = var.subdomain != "" ? "${var.subdomain}.${var.domain_name}" : var.domain_name

  statuses = ["ISSUED"]

  # Espera a que el certificado del módulo ACM esté emitido
  depends_on = [module.acm]
}

