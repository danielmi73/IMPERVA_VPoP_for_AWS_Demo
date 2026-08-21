# ==============================================================================
# NS1 DNS Integration for SSL Certificate Validation & CloudFront CNAME
# (Active only when set_alternative_domain = true)
# ==============================================================================

locals {
  # Auto-extract root domain / zone from alternative_domain_name if ns1_zone is not provided
  domain_parts_ns1 = split(".", var.alternative_domain_name)
  ns1_zone_name = var.ns1_zone != "" ? var.ns1_zone : (
    length(local.domain_parts_ns1) >= 2 ? join(".", slice(local.domain_parts_ns1, length(local.domain_parts_ns1) - 2, length(local.domain_parts_ns1))) : var.alternative_domain_name
  )
}

# 1. Request official Amazon ACM Certificate in us-east-1 (CloudFront requirement)
resource "aws_acm_certificate" "cf_cert" {
  count             = var.set_alternative_domain ? 1 : 0
  provider          = aws.us_east_1
  domain_name       = var.alternative_domain_name
  validation_method = "DNS"

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# 2. Request official Amazon ACM Certificate in deployment region (ALB HTTPS requirement)
resource "aws_acm_certificate" "alb_regional_acm" {
  count             = var.set_alternative_domain ? 1 : 0
  domain_name       = var.alternative_domain_name
  validation_method = "DNS"

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

# 3. Automatically create DNS CNAME validation records in NS1
resource "ns1_record" "acm_validation" {
  for_each = var.set_alternative_domain ? {
    for dvo in aws_acm_certificate.cf_cert[0].domain_validation_options : dvo.domain_name => {
      name   = trimsuffix(dvo.resource_record_name, ".")
      record = trimsuffix(dvo.resource_record_value, ".")
      type   = dvo.resource_record_type
    }
  } : {}

  zone   = local.ns1_zone_name
  domain = each.value.name
  type   = each.value.type
  ttl    = 60

  answers {
    answer = each.value.record
  }
}

# 4. Wait for CloudFront ACM DNS validation to complete in us-east-1
resource "aws_acm_certificate_validation" "cf_cert_validation" {
  count                   = var.set_alternative_domain ? 1 : 0
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cf_cert[0].arn
  validation_record_fqdns = [for record in ns1_record.acm_validation : record.domain]

  depends_on = [
    ns1_record.acm_validation
  ]
}

# 5. Wait for ALB ACM DNS validation to complete in deployment region
resource "aws_acm_certificate_validation" "alb_cert_validation" {
  count                   = var.set_alternative_domain ? 1 : 0
  certificate_arn         = aws_acm_certificate.alb_regional_acm[0].arn
  validation_record_fqdns = [for record in ns1_record.acm_validation : record.domain]

  depends_on = [
    ns1_record.acm_validation
  ]
}

# 6. Create NS1 CNAME record pointing alternative_domain_name -> CloudFront Distribution
resource "ns1_record" "cname_to_cloudfront" {
  count  = var.set_alternative_domain ? 1 : 0
  zone   = local.ns1_zone_name
  domain = trimsuffix(var.alternative_domain_name, ".")
  type   = "CNAME"
  ttl    = 60

  answers {
    answer = aws_cloudfront_distribution.demo_cf.domain_name
  }

  depends_on = [
    aws_cloudfront_distribution.demo_cf
  ]
}
