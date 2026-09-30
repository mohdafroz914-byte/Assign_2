terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# 1. S3 bucket with public access enabled
resource "aws_s3_bucket" "vulnerable_bucket" {
  bucket = "training-vulnerable-bucket-demo"

  tags = {
    Environment = "Training"
  }
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.vulnerable_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# 2. S3 bucket encryption disabled
resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.vulnerable_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 3. Security Group allowing SSH from anywhere
resource "aws_security_group" "vulnerable_sg" {
  name        = "vulnerable-security-group"
  description = "Intentionally vulnerable security group"

  ingress {
    description = "SSH from Internet"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 4. RDP exposed to Internet
  ingress {
    description = "RDP from Internet"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 5. All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 6. EC2 instance with public IP
resource "aws_instance" "vulnerable_instance" {
  ami           = "ami-0123456789abcdef0"
  instance_type = "t2.micro"

  associate_public_ip_address = true

  vpc_security_group_ids = [
    aws_security_group.vulnerable_sg.id
  ]

  # 7. Hard-coded password
  user_data = <<-EOF
    #!/bin/bash
    echo "admin_password=Password123!" > /tmp/config.txt
  EOF

  tags = {
    Name = "Vulnerable-Training-Server"
  }
}

# 8. IAM policy with excessive permissions
resource "aws_iam_policy" "admin_policy" {
  name = "training-overprivileged-policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "*",
      "Resource": "*"
    }
  ]
}
EOF
}

# 9. IAM user with access keys
resource "aws_iam_user" "training_user" {
  name = "training-admin-user"
}

# 10. RDS database with weak configuration
resource "aws_db_instance" "vulnerable_db" {
  identifier = "training-vulnerable-db"

  engine         = "mysql"
  engine_version = "8.0"

  instance_class        = "db.t3.micro"
  allocated_storage     = 20

  username = "admin"
  password = "Password123!"

  publicly_accessible = true

  skip_final_snapshot = true
}
