output "ec2_security_group_id" {
  description = "EC2 Security Group ID"
  value = aws_security_group.aws_sg.id
}
