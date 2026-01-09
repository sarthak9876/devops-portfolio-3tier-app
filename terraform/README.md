# Terraform Infrastructure

Infrastructure as Code for TaskMaster 3-tier application on AWS.

## Quick Start

# 1. Setup backend (first time only)
```
./backend-setup/setup-backend.sh dev ap-south-1
```

# 2. Navigate to environment
```
cd environments/dev
```

# 3. Configure variables
```
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

# 4. Deploy
```
terraform init
terraform plan
terraform apply
```
# Structure
```
modules/ - Reusable infrastructure components

environments/ - Environment-specific configs (dev, staging, prod)

backend-setup/ - S3 + DynamoDB setup scripts
```
# Documentation
See docs/terraform-usage.md for detailed guide.

Costs
Stays within AWS Free Tier ($0/month for first 12 months).
