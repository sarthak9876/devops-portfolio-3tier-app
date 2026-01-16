# ═══════════════════════════════════════════════════════
# VPC Module for TaskMaster
# Creates VPC, subnets, IGW, route tables
# ═══════════════════════════════════════════════════════

# Data: AZs if not explicitly passed
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}


resource "aws_vpc" "devops-project" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-vpc"
    }
  )
}


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.devops-project.id
  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-igw"
    }
  )
}

resource "aws_subnet" "public" {

  for_each = {
    for idx, az in local.azs :
    az => {
      az   = az
      cidr = var.public_subnet_cidrs[idx]
    }
  }

  vpc_id            = aws_vpc.devops-project.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  map_public_ip_on_launch = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-public-1a"
      Tier = "public"
    }
  )
}


resource "aws_subnet" "private" {

  for_each = {
    for idx, az in local.azs :
    az => {
      az   = az
      cidr = var.private_subnet_cidrs[idx]
    }
  }

  vpc_id            = aws_vpc.devops-project.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-private-1a"
      Tier = "private"
    }
  )
}


resource "aws_route_table" "public" {

  vpc_id = aws_vpc.devops-project.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-public-rt"
    }
  )
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.devops-project.id
  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-private-rt"
    }
  )
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
