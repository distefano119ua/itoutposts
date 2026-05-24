#----------------------------------------------------------
# My Terraform
# Provision:
#  - S3 Backend for remote Terraform state
#  - AWS Provider configuration
#  - Existing VPC lookup by tag
#  - Current public IP lookup for SSH access
#  - Web Security Group with HTTP, HTTPS and SSH access
#  - Private MongoDB Security Group with access from Web SG
#  Dmytro Shpatakovskyi
#------------------------Backend S3-------------------------

provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket = "dev-terraform-state-int26-39"
    key    = "dev/security/terraform.tfstate"
    region = "us-east-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}

#-------------------------AWS_VPC_ID & SSH Your IP---------------------------------

data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = "dev-terraform-state-int26-39"
    key    = "dev/network/terraform.tfstate"
    region = "us-east-1"
  }
}

data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

#------------------------Security Group Web-------------------------

resource "aws_security_group" "web" {
  name        = "${var.env}-terraform-web-sg"
  description = "Security group for web servers"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
  }

  ingress {
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

  tags = {
    Name = "${var.env}-terraform-web-sg"
  }
}

#------------------------Security Group Private MongoDB-------------------------

resource "aws_security_group" "mongodb" {
  name        = "${var.env}-terraform-mongodb-sg"
  description = "Security group for MongoDB servers"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  ingress {
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
    description     = "Allow MongoDB access from Web SG"
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
    description     = "Allow SSH access from Web SG"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.env}-terraform-mongodb-sg"
  }
}