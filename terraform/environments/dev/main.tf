# ═══════════════════════════════════════════════════════
# TaskMaster Development Environment
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

#VPC module

module "vpc" {
  source = "../../modules/vpc"

  project_name        = var.project_name
  environment         = var.environment
  aws_region          = var.aws_region
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  common_tags         = local.common_tags
}

# Security Module
module "security" {
  source = "../../modules/security"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  ssh_allowed_cidrs = var.ssh_allowed_cidrs
  common_tags       = local.common_tags
}

# Compute Module
module "compute" {
  source = "../../modules/compute"

  project_name        = var.project_name
  environment         = var.environment
  instance_type       = var.instance_type
  subnet_id           = module.vpc.public_subnet_id
  security_group_ids  = [module.security.ec2_security_group_id]
  ssh_public_key_path = var.ssh_public_key_path
  root_volume_size    = var.root_volume_size
  github_repo         = var.github_repo
  docker_user         = "ubuntu"
  common_tags         = local.common_tags
}

