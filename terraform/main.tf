
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Friendly name for tagging and resource naming"
  type        = string
  default     = "hello-app"
}

variable "environment_name" {
  description = "Elastic Beanstalk environment name (4-40 characters, no spaces)"
  type        = string
  default     = "hello-app-dev"
}

variable "vpc_id" {
  description = "Existing VPC ID where Elastic Beanstalk will run"
  type        = string
  default     = "vpc-341a2750"
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs in the target VPC"
  type        = list(string)
  default     = ["subnet-a1d44ed7", "subnet-471c6e7a"]
}

variable "instance_type" {
  description = "EC2 instance type for Elastic Beanstalk environment"
  type        = string
  default     = "t2.micro"
}

variable "jar_relative_path" {
  description = "Path to the application JAR relative to the terraform directory"
  type        = string
  default     = "../hello-app-final.jar"
}

locals {
  tags = {
    Project     = var.project_name
    Environment = var.environment_name
    ManagedBy   = "terraform"
  }

  jar_source_path = abspath("${path.module}/${var.jar_relative_path}")
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "artifacts" {
  bucket        = lower(replace("${var.project_name}-eb-artifacts-${random_id.bucket_suffix.hex}", "_", "-"))
  force_destroy = true

  tags = merge(local.tags, {
    Name = "${var.project_name}-eb-artifacts"
  })
}

resource "aws_s3_object" "app_bundle" {
  bucket = aws_s3_bucket.artifacts.id
  key    = "bundle/hello-app-final.jar"
  source = local.jar_source_path
  etag   = filemd5(local.jar_source_path)
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_security_group" "instance" {
  name        = "${var.project_name}-instance-sg"
  description = "Security group for Elastic Beanstalk EC2 instances"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${var.project_name}-instance-sg"
  })
}

data "aws_iam_policy_document" "instance_assume" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eb_instance" {
  name               = "${var.project_name}-eb-instance-role"
  assume_role_policy = data.aws_iam_policy_document.instance_assume.json

  tags = local.tags
}

resource "aws_iam_instance_profile" "eb_instance" {
  name = "${var.project_name}-eb-instance-profile"
  role = aws_iam_role.eb_instance.name
}

resource "aws_iam_role_policy_attachment" "eb_instance_web_tier" {
  role       = aws_iam_role.eb_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

resource "aws_iam_role_policy_attachment" "eb_instance_worker_tier" {
  role       = aws_iam_role.eb_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWorkerTier"
}

data "aws_iam_policy_document" "service_assume" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["elasticbeanstalk.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eb_service" {
  name               = "${var.project_name}-eb-service-role"
  assume_role_policy = data.aws_iam_policy_document.service_assume.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "eb_service_enhanced_health" {
  role       = aws_iam_role.eb_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkEnhancedHealth"
}

resource "aws_elastic_beanstalk_application" "app" {
  name        = var.project_name
  description = "Elastic Beanstalk application for ${var.project_name}"

  tags = local.tags
}

data "aws_elastic_beanstalk_solution_stack" "corretto17" {
  most_recent = true
  name_regex  = "^64bit Amazon Linux 2.*Corretto 17$"
}

resource "aws_elastic_beanstalk_application_version" "initial" {
  name        = "initial-version"
  application = aws_elastic_beanstalk_application.app.name
  description = "Initial version packaged from hello-app-final.jar"
  bucket      = aws_s3_bucket.artifacts.id
  key         = aws_s3_object.app_bundle.key
}

resource "aws_elastic_beanstalk_environment" "env" {
  name                = var.environment_name
  application         = aws_elastic_beanstalk_application.app.name
  solution_stack_name = data.aws_elastic_beanstalk_solution_stack.corretto17.name
  version_label       = aws_elastic_beanstalk_application_version.initial.name

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "SingleInstance"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = aws_iam_role.eb_service.name
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.eb_instance.name
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = var.instance_type
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "SecurityGroups"
    value     = aws_security_group.instance.id
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = var.vpc_id
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = join(",", var.public_subnet_ids)
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "PORT"
    value     = "5000"
  }

  tags = local.tags

  depends_on = [
    aws_iam_role_policy_attachment.eb_service_enhanced_health,
    aws_iam_role_policy_attachment.eb_instance_web_tier,
    aws_iam_role_policy_attachment.eb_instance_worker_tier,
    aws_s3_object.app_bundle
  ]
}

output "elastic_beanstalk_application_name" {
  description = "Elastic Beanstalk application name"
  value       = aws_elastic_beanstalk_application.app.name
}

output "elastic_beanstalk_environment_url" {
  description = "Elastic Beanstalk environment endpoint"
  value       = aws_elastic_beanstalk_environment.env.endpoint_url
}

output "vpc_id" {
  description = "ID of the VPC used for the environment"
  value       = var.vpc_id
}

output "artifact_bucket" {
  description = "S3 bucket used to store Elastic Beanstalk application bundles"
  value       = aws_s3_bucket.artifacts.bucket
}

