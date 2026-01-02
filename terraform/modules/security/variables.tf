variable "project_name" {
  description = "Project name"
  type = string
}

variable "environment" {
  description = "Environment"
  type = string
}

variable "vpc_id" {
  description = "VPC ID"
  type = string
}

variable "ssh_allowed_cidrs" {
  description = "SSH allowed cidr"
  type = list(string)
}



variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
