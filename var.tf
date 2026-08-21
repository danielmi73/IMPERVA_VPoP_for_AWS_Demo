variable "AWS_region" {
  description = "The AWS region to deploy resources in (e.g. us-east-1, eu-west-1)"
  type        = string
  default     = "us-east-1"
}

variable "tag_name" {
  description = "Name tag for identifying all project resources"
  type        = string
  default     = "imperva-vpop-demo-app"
}

variable "tag_owner_email" {
  description = "Email address of the resource owner"
  type        = string
}

variable "tag_manager_email" {
  description = "Email address of the resource owner's manager"
  type        = string
}

variable "tag_team_email" {
  description = "Email address of the team responsible for this environment"
  type        = string
}

variable "tag_description" {
  description = "Description tag for all deployed resources"
  type        = string
  default     = "vPoP Demo App for AWS"
}

variable "tag_environment" {
  description = "Environment identifier (e.g. SE Demo Lab, Production, Staging)"
  type        = string
  default     = "SE Demo Lab"
}

variable "tag_dataclassification" {
  description = "Data classification classification tag"
  type        = string
  default     = "THALES GROUP LIMITED DISTRIBUTION"
}

variable "incapsula_api_id" {
  description = "Imperva (Incapsula) Cloud WAF API ID"
  type        = string
  sensitive   = true
}

variable "incapsula_api_key" {
  description = "Imperva (Incapsula) Cloud WAF API Key"
  type        = string
  sensitive   = true
}

variable "alternative_domain_name" {
  description = "Domain name for the site onboarding in Imperva Cloud WAF (e.g. demo.yourdomain.com)"
  type        = string
}

variable "acm_certificate_arn" {
  description = "Optional ARN of an existing ACM certificate in your deployment region (e.g. il-central-1) to attach to the ALB. Leave empty to use auto-generated ACM certificate."
  type        = string
  default     = ""
}

variable "ns1_api_key" {
  description = "NS1 DNS API Key for automated DNS validation and CNAME record creation"
  type        = string
  sensitive   = true
  default     = ""
}

variable "set_alternative_domain" {
  description = "Whether to configure the alternative domain on CloudFront, validate SSL via NS1, and create CNAME in NS1"
  type        = bool
  default     = false
}

variable "ns1_zone" {
  description = "NS1 DNS Zone name (e.g. darc-syn.com). If empty, auto-extracted from alternative_domain_name."
  type        = string
  default     = ""
}
