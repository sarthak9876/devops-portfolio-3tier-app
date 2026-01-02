# ═══════════════════════════════════════════════════════
# Compute Module - EC2 Instance for TaskMaster
# ═══════════════════════════════════════════════════════


data "aws_ami" "ubuntu" {
  most_recent = true
  owners = ["099720109477"] # Canonical

  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name =  "virtualization-type"
    values = ["hvm"]
  }
}


resource "aws_key_pair" "taskmaster" {
  key_name = "${var.project_name}-${var.environment}-kp"
  public_key = file(var.ssh_public_key_path)

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-keypair"
    }
  )
}


resource "aws_instance" "taskmaster" {
  ami = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  key_name = aws_key_pair.taskmaster.key_name

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    delete_on_termination = true
    encrypted = true
   
    tags = merge(
      var.common_tags,
      {
        Name = "${var.project_name}-${var.environment}-root-volume"
      }
    )
  }
  user_data = templatefile("${path.module}/user_data.sh", {
    github_repo   = var.github_repo
    docker_user   = var.docker_user
  })

  metadata_options {
    http_endpoint = "enabled"
    http_tokens = "required"
    
    http_put_response_hop_limit = 1
  }
  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-instance"
    }
  )
}
