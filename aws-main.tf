provider "aws" {
  region = "us-east-1" # Update with your desired region
}

variable "vpc_cidr_block" {
  description = "CIDR block for VPC"
  default     = "10.0.0.0/16" # Update with your desired CIDR block
}

variable "subnet_cidr_block" {
  description = "CIDR block for subnet"
  default     = "10.0.0.0/24" # Update with your desired CIDR block
}

variable "instance_ami" {
  description = "AMI ID for EC2 instance"
  default     = "ami-0261755bbcb8c4a84" # Update with your desired AMI ID
}

variable "instance_type" {
  description = "Instance type for EC2 instance"
  default     = "t2.micro" # Update with your desired instance type
}

resource "aws_vpc" "example" {
  cidr_block = var.vpc_cidr_block

  tags = {
    Name = "MyVPC"
  }
}

resource "aws_key_pair" "example" {
  key_name   = "keypairname"
  public_key = file("myEC2instance.pub")
}

resource "tls_private_key" "demo_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_subnet" "example" {
  vpc_id     = aws_vpc.example.id
  cidr_block = var.subnet_cidr_block

  tags = {
    Name = "MySubnet"
  }
}

resource "aws_security_group" "example" {
  name        = "example_sg"
  description = "Example security group"
  vpc_id      = aws_vpc.example.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["14.143.216.186/32"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "example" {
  ami           = var.instance_ami
  instance_type = var.instance_type
  subnet_id     = aws_subnet.example.id
  key_name      = aws_key_pair.example.key_name

  connection {
    type        = "ssh"
    user        = "ubuntu"  # Replace with the appropriate user for your AMI
    private_key = file("myEC2instance.pub")  # Replace with the path to your private key
    host        = self.public_ip
  }

  tags = {
    Name = "MyEC2Instance"
  }
}

resource "aws_ebs_volume" "example" {
  availability_zone = aws_instance.example.availability_zone
  size              = 60  # Replace with your desired volume size in GB
  tags = {
    Name = "example_volume"
  }
}

resource "aws_volume_attachment" "example" {
  device_name = "/dev/sdf"  # Replace with your desired device name
  volume_id   = aws_ebs_volume.example.id
  instance_id = aws_instance.example.id
}


resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.example.id
}

resource "aws_eip" "example" {
  vpc                       = true
  instance                  = aws_instance.example.id
  associate_with_private_ip = aws_instance.example.private_ip

  tags = {
    Name = "MyEIP"
  }
}

resource "aws_cloudfront_distribution" "example" {
  origin {
    domain_name = "my-bucket.s3.amazonaws.com"
    origin_id   = "MyOrigin"
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "My CloudFront Distribution"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "MyOrigin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "MyCloudFrontDistribution"
  }
}

resource "aws_wafv2_web_acl" "example" {
  name        = "MyWebACL"
  description = "Web ACL for CloudFront"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "AllowAll"
    priority = 1
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    override_action {
      none {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AllowAll"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "MyWebACL"
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_association" "MyCloudFrontDistribution" {
  resource_arn = aws_cloudfront_distribution.example.arn
  web_acl_arn  = aws_wafv2_web_acl.example.arn
}
