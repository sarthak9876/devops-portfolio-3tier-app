#!/bin/bash
# Start all AWS resources
# Run this when you're ready to work on the project

set -e

echo "🚀 Starting AWS Resources..."
echo ""

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &>/dev/null; then
    echo "❌ AWS CLI not configured. Run 'aws configure' first."
    exit 1
fi

# Get default region
AWS_REGION=$(aws configure get region)
echo "Region: $AWS_REGION"
echo ""

# Start stopped EC2 instances
echo "🔍 Finding stopped EC2 instances..."
INSTANCE_IDS=$(aws ec2 describe-instances \
    --region $AWS_REGION \
    --filters "Name=instance-state-name,Values=stopped" "Name=tag:Project,Values=devops-portfolio" \
    --query "Reservations[*].Instances[*].InstanceId" \
    --output text)

if [ -z "$INSTANCE_IDS" ]; then
    echo "ℹ️  No stopped instances found (either running or not created yet)"
else
    echo "🚀 Starting instances: $INSTANCE_IDS"
    aws ec2 start-instances --region $AWS_REGION --instance-ids $INSTANCE_IDS
    
    echo "⏳ Waiting for instances to be running..."
    aws ec2 wait instance-running --region $AWS_REGION --instance-ids $INSTANCE_IDS
    
    echo "✅ All instances are running!"
fi

echo ""
echo "✅ Resources started! Ready to work on your project."
echo ""
echo "Next steps:"
echo "   1. Check EC2 console for new public IPs"
echo "   2. Update kubectl config if K8s cluster IPs changed"
echo "   3. Verify application is accessible"
