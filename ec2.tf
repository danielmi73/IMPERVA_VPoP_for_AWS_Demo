# ==============================================================================
# EC2 Compute & Demo Application Packaging
# ==============================================================================

locals {
  common_tags = {
    Name               = var.tag_name
    Owner              = var.tag_owner_email
    Manager            = var.tag_manager_email
    Team               = var.tag_team_email
    Description        = var.tag_description
    Environment        = var.tag_environment
    DataClassification = var.tag_dataclassification
    ManagedBy          = "Terraform"
  }
}

# Fetch latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Unique suffix for S3 bucket
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 Bucket for Demo App Assets & Package
resource "aws_s3_bucket" "app_bucket" {
  bucket        = "${lower(replace(var.tag_name, "_", "-"))}-assets-${random_id.bucket_suffix.hex}"
  force_destroy = true

  tags = local.common_tags
}

# Block all public access to the S3 bucket
resource "aws_s3_bucket_public_access_block" "app_bucket_pab" {
  bucket = aws_s3_bucket.app_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable Server-Side Encryption on S3 Bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "app_bucket_enc" {
  bucket = aws_s3_bucket.app_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Package the entire demo app directory into a zip archive
data "archive_file" "app_zip" {
  type        = "zip"
  source_dir  = "${path.module}/app"
  output_path = "${path.module}/app.zip"
}

# Upload App Package to S3
resource "aws_s3_object" "app_package" {
  bucket = aws_s3_bucket.app_bucket.id
  key    = "app.zip"
  source = data.archive_file.app_zip.output_path
  etag   = data.archive_file.app_zip.output_md5
}

# IAM Role for EC2 (SSM Session Manager + S3 Read)
resource "aws_iam_role" "ec2_ssm_role" {
  name = "${var.tag_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# Attach SSM Policy for keyless terminal access
resource "aws_iam_role_policy_attachment" "ssm_attachment" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Policy allowing EC2 instance to download the app package from S3
resource "aws_iam_policy" "s3_read_policy" {
  name        = "${var.tag_name}-s3-read-policy"
  description = "Allow EC2 instance to download demo app archive from S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.app_bucket.arn}/*"
      }
    ]
  })

  tags = local.common_tags
}

# Attach S3 Policy to EC2 Role
resource "aws_iam_role_policy_attachment" "s3_attachment" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = aws_iam_policy.s3_read_policy.arn
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.tag_name}-ec2-profile"
  role = aws_iam_role.ec2_ssm_role.name

  tags = local.common_tags
}

# EC2 Instance running OWASP Demo Web Application
resource "aws_instance" "demo_app" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  # Encrypted root block device
  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }

  # Mandatory volume tags for AWS Organizations SCP compliance
  volume_tags = local.common_tags
  tags        = local.common_tags

  # Compact user_data (< 1 KB) downloading app package from S3
  user_data = <<-EOF
              #!/bin/bash
              set -e

              # Install dependencies
              dnf update -y
              dnf install -y python3 python3-pip unzip awscli

              # Install Flask and Gunicorn
              pip3 install flask gunicorn

              # Download and extract application from S3
              mkdir -p /opt/demo-app
              aws s3 cp s3://${aws_s3_bucket.app_bucket.id}/app.zip /tmp/app.zip --region ${var.AWS_region}
              unzip -o /tmp/app.zip -d /opt/demo-app

              # Create Systemd Service for OWASP Demo App
              cat <<'SERVICE_EOF' > /etc/systemd/system/owasp-demo.service
              [Unit]
              Description=OWASP Top 10 Demo Web App for Imperva Cloud WAF
              After=network.target

              [Service]
              User=root
              WorkingDirectory=/opt/demo-app
              ExecStart=/usr/bin/python3 -m gunicorn --bind 0.0.0.0:80 --workers 4 app:app
              Restart=always
              RestartSec=5

              [Install]
              WantedBy=multi-user.target
              SERVICE_EOF

              # Enable and start the service
              systemctl daemon-reload
              systemctl enable owasp-demo.service
              systemctl start owasp-demo.service
              EOF

  depends_on = [
    aws_s3_object.app_package
  ]
}
