output "vpc_id" {
  description = "ID of VPC"
  value       = aws_vpc.devops-project.id
}

output "vpc_cidr" {
  description = "CIDR value of VPC"
  value       = aws_vpc.devops-project.cidr_block
}

output "internet_gateway_id" {
  description = " Internet Gateway ID"
  value       = aws_internet_gateway.igw.id
}



output "public_subnet_ids" {
  description = "IDs of public subnets (multi-AZ)"
  value       = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  description = "IDs of private subnets (multi-AZ)"
  value       = [for s in aws_subnet.private : s.id]
}


output "public_subnet_id" {
  description = "ID of first public subnet (for compute module)"
  value       = values(aws_subnet.public)[0].id
}

# Backward compatibility: Return first private subnet
output "private_subnet_id" {
  description = "ID of first private subnet"
  value       = values(aws_subnet.private)[0].id
}
