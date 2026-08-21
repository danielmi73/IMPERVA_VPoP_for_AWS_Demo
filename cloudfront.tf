# ==============================================================================
# AWS CloudFront Distribution with Imperva for AWS (vPoP) Integration
# ==============================================================================

# Lookup AWS Managed Origin Request Policy: AllViewerAndCloudFrontHeaders-2022-06
data "aws_cloudfront_origin_request_policy" "all_viewer_and_cloudfront_headers" {
  name = "Managed-AllViewerAndCloudFrontHeaders-2022-06"
}

# Lookup AWS Managed Cache Policy: CachingDisabled (ensures all dynamic attacks are inspected)
data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

# CloudFront Distribution pointing to Imperva Origin Domain with x-impv-origin-domain Header
resource "aws_cloudfront_distribution" "demo_cf" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Imperva for AWS (vPoP) CloudFront Distribution"
  default_root_object = ""

  # Optional alternate domain name (CNAME)
  aliases = var.set_alternative_domain ? [var.alternative_domain_name] : []

  # Origin configured with Imperva Origin Domain (CNAME) and x-impv-origin-domain Header
  origin {
    domain_name = local.imperva_origin_domain
    origin_id   = "imperva-cloud-waf-origin"

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "https-only"
      origin_ssl_protocols     = ["TLSv1.2"]
      origin_read_timeout      = 30
      origin_keepalive_timeout = 5
    }

    # Imperva required custom header
    custom_header {
      name  = "x-impv-origin-domain"
      value = local.imperva_origin_domain
    }
  }

  # Default Cache Behavior with AllViewerAndCloudFrontHeaders origin request policy
  default_cache_behavior {
    target_origin_id       = "imperva-cloud-waf-origin"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods  = ["GET", "HEAD"]

    # Use AWS Managed AllViewerAndCloudFrontHeaders Policy
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer_and_cloudfront_headers.id

    # Disable caching so all dynamic attacks reach Imperva WAF for inspection
    cache_policy_id = data.aws_cloudfront_cache_policy.caching_disabled.id

    compress = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn            = var.set_alternative_domain ? aws_acm_certificate_validation.cf_cert_validation[0].certificate_arn : null
    ssl_support_method             = var.set_alternative_domain ? "sni-only" : null
    minimum_protocol_version       = var.set_alternative_domain ? "TLSv1.2_2021" : null
    cloudfront_default_certificate = var.set_alternative_domain ? false : true
  }

  tags = {
    Name = "${var.tag_name}-cf"
  }

  depends_on = [
    incapsula_site_v3.aws_site,
    incapsula_cloud_origin_domain.origin
  ]
}
