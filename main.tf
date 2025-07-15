provider "aws" {
  region = var.aws_region
}

# Role para o Beanstalk gerenciar o ambiente
resource "aws_iam_role" "beanstalk_service_role" {
  name = "beanstalk-service-role2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "elasticbeanstalk.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "beanstalk_service_attach" {
  role       = aws_iam_role.beanstalk_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkService"
}

# Role para a EC2
resource "aws_iam_role" "beanstalk_ec2_role" {
  name = "beanstalk-ec2-role2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "beanstalk_ec2_attach" {
  role       = aws_iam_role.beanstalk_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

resource "aws_iam_instance_profile" "beanstalk_ec2_profile" {
  name = "beanstalk-ec2-profile2"
  role = aws_iam_role.beanstalk_ec2_role.name
}

# Aplicação
resource "aws_elastic_beanstalk_application" "app" {
  name        = var.app_name
  description = "Aplicação de exemplo sem Load Balancer"
}


# Ambiente - modo SingleInstance (sem Load Balancer)
resource "aws_elastic_beanstalk_environment" "env" {
  name                = "${var.app_name}-env"
  application         = aws_elastic_beanstalk_application.app.name
  solution_stack_name = "64bit Amazon Linux 2023 v6.6.0 running Node.js 18"

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.beanstalk_ec2_profile.name
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = aws_iam_role.beanstalk_service_role.arn
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "SingleInstance"
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = var.vpc_id
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = join(",", var.subnet_ids)
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = "true"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "SecurityGroups"
    value     = aws_security_group.beanstalk_sg.id
  }
}


resource "aws_security_group" "beanstalk_sg" {
  name        = "beanstalk-sg"
  description = "SG para ambiente Beanstalk sem Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


variable "aws_region" {
  default = "us-east-1"
}

variable "app_name" {
  default = "sample-beanstalk-app"
}

variable "vpc_id" {
  default = "vpc-0a6c7ede329f561c5"
}

variable "subnet_ids" {
  description = "Lista de subnets públicas da VPC"
  type        = list(string)
  # Substitua pelos seus IDs reais de subnets públicas
  default     = ["subnet-098263c71a8b36414", "subnet-0430d0b8249ed4f1d"]
}
