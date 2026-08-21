# ==============================================================================
# Imperva (Incapsula) Cloud WAF Configuration for AWS (vPoP)
# Uses Public Cloud AWS Site (v3) and Cloud Origin Domain
# ==============================================================================

# Create Public Cloud AWS Site in Imperva
resource "incapsula_site_v3" "aws_site" {
  name       = var.alternative_domain_name
  type       = "PUBLIC_CLOUD"
  cloud_type = "AWS"
  ref_id     = var.tag_name

  depends_on = [
    aws_lb.demo_alb,
    aws_lb_listener.demo_http,
    aws_lb_listener.demo_https
  ]
}

# Attach AWS Cloud Origin Domain (ALB DNS) to the Imperva Site
# When set_alternative_domain = true: Uses official validated ACM certificate via HTTPS:443 (TLS 1.2)
# When set_alternative_domain = false: Uses HTTP:80 without origin certificate mismatch
resource "incapsula_cloud_origin_domain" "origin" {
  account_id          = incapsula_site_v3.aws_site.account_id
  site_id             = incapsula_site_v3.aws_site.id
  domain              = aws_lb.demo_alb.dns_name
  region              = var.AWS_region
  origin_ssl_protocol = var.set_alternative_domain ? "TLS_1_2" : null
  port                = var.set_alternative_domain ? 443 : 80

  depends_on = [
    incapsula_site_v3.aws_site,
    aws_lb.demo_alb,
    aws_lb_listener.demo_http,
    aws_lb_listener.demo_https
  ]
}

# Local variable for the generated Imperva Origin Domain (e.g. *.origins.<region>.vpop.imperva.com)
locals {
  imperva_origin_domain = incapsula_cloud_origin_domain.origin.imperva_origin_domain
}
