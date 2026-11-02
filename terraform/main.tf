terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "eu-north-1"
}

data "aws_vpc" "default" {
  default = true
}

output "vpc_id" {
  value = data.aws_vpc.default.id
}


data "aws_ssm_parameter" "amazon_linux" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "app" {
  ami                  = data.aws_ssm_parameter.amazon_linux.value
  instance_type        = "t3.micro"
  iam_instance_profile = aws_iam_instance_profile.app.name
  depends_on           = [aws_iam_role_policy_attachment.ssm]
  metadata_options {
    http_tokens = "required"
  }
  subnet_id                   = data.aws_subnet.default.id
  associate_public_ip_address = true
  credit_specification {
    cpu_credits = "standard"
  }

  tags = {
    Name = "devops-playground"
  }

  vpc_security_group_ids = [aws_security_group.app.id]
}
resource "aws_iam_role" "app" {
  name = "devops-playground-ec2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "app" {
  name = "devops-playground-ec2"
  role = aws_iam_role.app.name
}
resource "aws_security_group" "app" {
  name        = "devops-playground"
  description = "Access to the practice app"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name = "devops-playground"
  }
}

resource "aws_vpc_security_group_ingress_rule" "app_http" {
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "app_outbound" {
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
data "aws_subnet" "default" {
  availability_zone = "eu-north-1a"
  default_for_az    = true
}

output "app_public_ip" {
  value = aws_instance.app.public_ip
}