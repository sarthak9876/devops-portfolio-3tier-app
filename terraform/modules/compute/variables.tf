variable "project_name" {
  description = "Project name"
  type = string
}

variable "environment" {
  description = "Environment"
  type = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type = string
  default = "m7i-flex.large"
}

variable "subnet_id" {
  description = "Subnet ID for EC2"
  type= string
}

variable "security_group_ids" {
  description = "Security Group IDs"
  type = list(string)
}

variable "ssh_public_key_path" {
  description = "SSH public key path"
  type = string
}

variable "root_volume_size" {
  description = "Root volume size for EC2"
  type = number
  default = 30
}

variable "github_repo" {
  description = "Github Repo URL"
  type = string
}

variable "docker_user" {
  description = "Docker User details (default = ubuntu)"
  type = string
  default = "ubuntu"
}


variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
