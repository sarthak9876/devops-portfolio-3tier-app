# ═══════════════════════════════════════════════════════
# VPC Module for TaskMaster
# Creates VPC, subnets, IGW, route tables
# ═══════════════════════════════════════════════════════

resource "aws_vpc" "devops-project" {
  cidr_block = var.vpc_cidr
  enable_dns_support = true
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
  vpc_id = aws_vpc.devops-project.id
  cidr_block = var.public_subnet_cidr
  availability_zone = "${var.aws_region}a"
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
  vpc_id = aws_vpc.devops-project.id
  cidr_block = var.private_subnet_cidr
  availability_zone = "${var.aws_region}a"

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
  subnet_id = aws_subnet.public.id
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
  subnet_id = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}
   


