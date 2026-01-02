# ═══════════════════════════════════════════════════════
# Security Groups Module
# Creates security groups for EC2 and future DB
# ═══════════════════════════════════════════════════════


resource "aws_security_group" "aws_sg" {
  name = "${var.project_name}-${var.environment}-sg"
  description = "Security group for DevOps Project"
  vpc_id = var.vpc_id

  #SSH
  ingress {
    description = "SSH allowed access"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = var.ssh_allowed_cidrs
  }


  #Frontend
  ingress {
    description = "Frontend access"
    from_port = 3000
    to_port = 3000
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #Backend
  ingress {
    description = "Backend access"
    from_port = 5000
    to_port = 5000
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #HTTP
  ingress {
    description = "HTTP access"
    from_port = 80
    to_port = 80 
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  #HTTPS
  ingress {
    description = "HTTPS access"
    from_port = 443
    to_port = 443 
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
   
    tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-ec2-sg"
    }
  )
}
