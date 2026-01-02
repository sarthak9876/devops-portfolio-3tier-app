output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.taskmaster.id
}

output "instance_public_ip" {
  description = "Public IP of EC2 instance"
  value       = aws_instance.taskmaster.public_ip
}

output "instance_private_ip" {
  description = "Private IP of EC2 instance"
  value       = aws_instance.taskmaster.private_ip
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh -i ~/.ssh/${var.project_name}-${var.environment}.pem ubuntu@${aws_instance.taskmaster.public_ip}"
}

output "frontend_url" {
  description = "TaskMaster Frontend URL"
  value       = "http://${aws_instance.taskmaster.public_ip}:3000"
}

output "backend_url" {
  description = "TaskMaster Backend URL"
  value       = "http://${aws_instance.taskmaster.public_ip}:5000"
}
