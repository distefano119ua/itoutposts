#----------------------------------------------------------
# Provision:
#  - VPC
#  - Internet Gateway
#  - XX Public Subnets
#  - XX Private Subnets
#  - XX NAT Gateways in Public Subnets to give access to Internet from Private Subnets
#  Dmytro Shpatakovskyi
#------------------------Backend S3-------------------------

provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket = "dev-terraform-state-int26-39"
    key    = "dev/network/terraform.tfstate"
    region = "us-east-1"
  }
}

#-------------------------Main VPC-----------------------

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  region     = var.region
  tags = {
    Name = "${var.env}-terraform-vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.env}-terraform-igw"
  }
}

#------------------Public Subnets & Routing------------------------
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.env}-terraform-public-subnet-${var.availability_zones[count.index]}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "${var.env}-terraform-public-rt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

#------------------NAT Gateway Jumpbox with EIPs------------------------


resource "aws_eip" "jumpbox" {
  domain = "vpc"
  tags = {
    Name = "${var.env}-terraform-jumpbox-eip-${var.availability_zones[0]}"
  }
}

resource "aws_nat_gateway" "jumpbox" {
  allocation_id = aws_eip.jumpbox.id
  subnet_id     = aws_subnet.public[0].id
  tags = {
    Name = "${var.env}-terraform-jumpbox-nat-${var.availability_zones[0]}"
  }
}

#------------------Private Subnets & Routing------------------------

resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  tags = {
    Name = "${var.env}-terraform-private-subnet-${var.availability_zones[count.index]}"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.jumpbox.id
  }
  tags = {
    Name = "${var.env}-terraform-private-rt"
  }
}

resource "aws_route_table_association" "private_assoc" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
