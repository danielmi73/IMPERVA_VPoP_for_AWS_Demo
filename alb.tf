# ==============================================================================
# AWS Application Load Balancer (ALB) with HTTP & HTTPS Listeners and Rules
# ==============================================================================

# Application Load Balancer
resource "aws_lb" "demo_alb" {
  name               = substr("${var.tag_name}-alb", 0, 32)
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  enable_deletion_protection = false

  tags = local.common_tags
}

# Target Group for Demo App
resource "aws_lb_target_group" "demo_tg" {
  name        = substr("${var.tag_name}-tg", 0, 32)
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    port                = "80"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = local.common_tags
}

# ------------------------------------------------------------------------------
# Port 80 HTTP Listener & Rules
# ------------------------------------------------------------------------------

# ALB HTTP Listener (Port 80)
resource "aws_lb_listener" "demo_http" {
  load_balancer_arn = aws_lb.demo_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.demo_tg.arn
  }

  tags = merge(local.common_tags, {
    Name = "${var.tag_name}-listener-80"
  })
}

# ALB HTTP Listener Rule - Forward all paths to Target Group
resource "aws_lb_listener_rule" "http_forward_rule" {
  listener_arn = aws_lb_listener.demo_http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.demo_tg.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.tag_name}-http-rule-all"
  })
}

# ------------------------------------------------------------------------------
# Port 443 HTTPS Listener & Rules
# ------------------------------------------------------------------------------

# Generate TLS Private Key for ALB HTTPS Listener
resource "tls_private_key" "alb_cert_key" {
  algorithm = "RSA"
  rsa_bits  = 2048

  lifecycle {
    create_before_destroy = true
  }
}

# Generate TLS Certificate for ALB matching the site domain
resource "tls_self_signed_cert" "alb_cert" {
  private_key_pem = tls_private_key.alb_cert_key.private_key_pem

  subject {
    common_name  = var.alternative_domain_name
    organization = "Imperva Demo Lab"
  }

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]

  lifecycle {
    create_before_destroy = true
  }
}

# Import Certificate into AWS ACM in ALB's region
resource "aws_acm_certificate" "alb_self_signed" {
  private_key      = tls_private_key.alb_cert_key.private_key_pem
  certificate_body = tls_self_signed_cert.alb_cert.cert_pem

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

locals {
  alb_certificate_arn = var.acm_certificate_arn != "" ? var.acm_certificate_arn : (
    var.set_alternative_domain ? aws_acm_certificate_validation.alb_cert_validation[0].certificate_arn : aws_acm_certificate.alb_self_signed.arn
  )
}

# ALB HTTPS Listener (Port 443 - Required for Full End-to-End TLS)
resource "aws_lb_listener" "demo_https" {
  load_balancer_arn = aws_lb.demo_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = local.alb_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.demo_tg.arn
  }

  tags = merge(local.common_tags, {
    Name = "${var.tag_name}-listener-443"
  })
}

# ALB HTTPS Listener Rule - Forward all paths to Target Group
resource "aws_lb_listener_rule" "https_forward_rule" {
  listener_arn = aws_lb_listener.demo_https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.demo_tg.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.tag_name}-https-rule-all"
  })
}

# ------------------------------------------------------------------------------
# Target Group Attachment
# ------------------------------------------------------------------------------
resource "aws_lb_target_group_attachment" "demo_tga" {
  target_group_arn = aws_lb_target_group.demo_tg.arn
  target_id        = aws_instance.demo_app.id
  port             = 80
}
