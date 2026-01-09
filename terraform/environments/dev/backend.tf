# ═══════════════════════════════════════════════════════
# Terraform Remote State Backend (S3 + DynamoDB)
# Region: us-east-1
# ═══════════════════════════════════════════════════════

terraform {
  backend "s3" {
    bucket         = "taskmaster-terraform-state-364218291713"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "taskmaster-terraform-lock"
  }
}



