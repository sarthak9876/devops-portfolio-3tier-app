#!/bin/bash

# Set variables for us-east-1
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="taskmaster-terraform-state-${AWS_ACCOUNT_ID}"
DYNAMODB_TABLE="taskmaster-terraform-lock"

# Check if bucket exists
if aws s3 ls s3://$BUCKET_NAME --region us-east-1 2>/dev/null; then
    echo "✅ Bucket exists in us-east-1: $BUCKET_NAME"
else
    echo "Creating bucket in us-east-1..."
    # us-east-1 doesn't need LocationConstraint
    aws s3api create-bucket \
      --bucket "$BUCKET_NAME" \
      --region us-east-1
fi

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --region us-east-1 \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --region us-east-1 \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --region us-east-1 \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Check if DynamoDB table exists
if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region us-east-1 2>/dev/null; then
    echo "✅ DynamoDB table exists in us-east-1: $DYNAMODB_TABLE"
else
    echo "Creating DynamoDB table in us-east-1..."
    aws dynamodb create-table \
      --table-name "$DYNAMODB_TABLE" \
      --attribute-definitions AttributeName=LockID,AttributeType=S \
      --key-schema AttributeName=LockID,KeyType=HASH \
      --billing-mode PAY_PER_REQUEST \
      --region us-east-1 \
      --tags Key=Project,Value=TaskMaster Key=ManagedBy,Value=Terraform
    
    aws dynamodb wait table-exists --table-name "$DYNAMODB_TABLE" --region us-east-1
fi

echo ""
echo "✅ Backend resources ready in us-east-1"
echo "Bucket: $BUCKET_NAME"
echo "DynamoDB: $DYNAMODB_TABLE"
