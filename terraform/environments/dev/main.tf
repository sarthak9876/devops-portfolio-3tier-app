# ═══════════════════════════════════════════════════════
# TaskMaster Development Environment
# Multi-AZ VPC + EKS + EC2
# ═══════════════════════════════════════════════════════

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
  }
}

# ═══════════════════════════════════════════════════════
# VPC Module (Multi-AZ)
# ═══════════════════════════════════════════════════════

module "vpc" {
  source = "../../modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  aws_region           = var.aws_region
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  common_tags          = local.common_tags
}

# ═══════════════════════════════════════════════════════
# Security Module
# ═══════════════════════════════════════════════════════

module "security" {
  source = "../../modules/security"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  ssh_allowed_cidrs = var.ssh_allowed_cidrs
  common_tags       = local.common_tags
}

# ═══════════════════════════════════════════════════════
# Compute Module (EC2 with Docker Compose)
# ═══════════════════════════════════════════════════════

module "compute" {
  source = "../../modules/compute"

  project_name  = var.project_name
  environment   = var.environment
  instance_type = var.instance_type

  # Use first public subnet from multi-AZ list
  subnet_id = module.vpc.public_subnet_ids[0]

  security_group_ids  = [module.security.ec2_security_group_id]
  ssh_public_key_path = var.ssh_public_key_path
  root_volume_size    = var.root_volume_size
  github_repo         = var.github_repo
  docker_user         = "ubuntu"
  common_tags         = local.common_tags
}

# ═══════════════════════════════════════════════════════
# EKS Module (Kubernetes Cluster)
# ═══════════════════════════════════════════════════════

module "eks" {
  source = "../../modules/eks"

  project_name    = var.project_name
  environment     = var.environment
  cluster_version = "1.30"
  vpc_id          = module.vpc.vpc_id

  # Pass ALL public subnets (multi-AZ) to satisfy EKS requirement
  public_subnet_ids = module.vpc.public_subnet_ids

  # Pass private subnets for future use
  private_subnet_ids = module.vpc.private_subnet_ids

  node_instance_type = var.eks_node_instance_type
  desired_capacity   = var.eks_desired_capacity
  min_size           = var.eks_min_size
  max_size           = var.eks_max_size

  common_tags = local.common_tags
}
