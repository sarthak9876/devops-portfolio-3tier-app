output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "instance_id" {
  description = "EC2 Instance ID"
  value       = module.compute.instance_id
}

output "instance_public_ip" {
  description = "EC2 Public IP"
  value       = module.compute.instance_public_ip
}

output "ssh_command" {
  description = "SSH connection command"
  value       = module.compute.ssh_command
}

output "frontend_url" {
  description = "Frontend URL"
  value       = module.compute.frontend_url
}

output "backend_url" {
  description = "Backend URL"
  value       = module.compute.backend_url
}

