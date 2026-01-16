variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev/staging/procution)"
  type        = string
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
}

variable "availability_zones" {
  description = "List of AZs to use"
  type        = list(string)
  default     = []
}


variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

#variable "public_subnet_cidr" {
#  description = "CIDR block for public subnet"
#  type        = string
#}


variable "public_subnet_cidrs" {
  description = "CIDR block for public subnet"
  type        = list(string)
}

#variable "private_subnet_cidr"{
# type = string
#description = "PRivate subnet CIDR value"
#}
variable "private_subnet_cidrs" {
  description = "CIDR block for private subnet"
  type        = list(string)
  default     = []
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
