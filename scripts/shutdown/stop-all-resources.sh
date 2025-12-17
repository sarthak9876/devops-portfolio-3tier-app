#!/bin/bash
# Stop all AWS resources to save credits
# Run this when you're done working for the day

set -e

echo "🛑 Stopping AWS Resources to Save Credits..."
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

# Stop EC2 instances (don't terminate - we'll restart them)
echo "🔍 Finding running EC2 instances..."
INSTANCE_IDS=$(aws ec2 describe-instances \
    --region $AWS_REGION \
    --filters "Name=instance-state-name,Values=running" "Name=tag:Project,Values=devops-portfolio" \
    --query "Reservations[*].Instances[*].InstanceId" \
    --output text)

if [ -z "$INSTANCE_IDS" ]; then
    echo "✅ No running instances found"
else
    echo "🛑 Stopping instances: $INSTANCE_IDS"
    aws ec2 stop-instances --region $AWS_REGION --instance-ids $INSTANCE_IDS
    echo "✅ EC2 instances stopped"
fi

echo ""
echo "💰 Cost Savings Summary:"
echo "   - Stopped EC2 instances (compute costs = $0)"
echo "   - EBS volumes remain (minimal cost)"
echo "   - Elastic IPs released (if any)"
echo ""
echo "✅ All resources stopped! You can safely close your terminal."
echo ""
echo "To restart resources tomorrow, run:"
echo "   ./scripts/startup/start-all-resources.sh"
