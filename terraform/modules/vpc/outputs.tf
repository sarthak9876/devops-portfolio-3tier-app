output "vpc_id" {
  description = "ID of VPC"
  value = aws_vpc.devops-project.id
}

output "vpc_cidr" {
  description = "CIDR value of VPC"
  value = aws_vpc.devops-project.cidr_block
}

output "public_subnet_id" { 
  description = "Public Subet ID"
  value = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "Private subnet ID"
  value = aws_subnet.private.id
}

output "internet_gateway_id" {
  description = " Internet Gateway ID"
  value = aws_internet_gateway.igw.id
}
