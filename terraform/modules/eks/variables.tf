variable "project_name" {
  type        = string
  description = "devops-3tier-project"
}

variable "environment" {
  type        = string
  description = "Environment (dev/staging/production)"
}

variable "cluster_version" {
  type        = string
  description = "Kubernetes Cluster version"
  default     = "1.30"
}
variable "vpc_id" {
  type        = string
  description = "VPC Id wehre EKS will bed eployed"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Last of public subnet IDs where EKS cluster nodes will be there"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of Private Subnet IDs for Node group and LBs"
  default     = []
}


variable "node_instance_type" {
  type        = string
  description = "Instance type of worker node of cluster"
  default     = "m7i-flex.large"
}

variable "desired_capacity" {
  type        = number
  description = "Desired number of worker nodes"
  default     = 1
}

variable "min_size" {
  type        = number
  description = "Minimum number of worker nodes"
  default     = 1
}

variable "max_size" {
  type        = number
  description = "Max number of worker nodes"
  default     = 2
}

variable "common_tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default     = {}
}
