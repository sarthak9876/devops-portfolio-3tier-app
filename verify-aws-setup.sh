#!/bin/bash
# AWS Setup Verification Script

set -e

echo "═══════════════════════════════════════════════════════"
echo "AWS SETUP VERIFICATION"
echo "═══════════════════════════════════════════════════════"
echo ""

# 1. Check AWS CLI installation
echo "1. Checking AWS CLI installation..."
if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version)
    echo "   ✅ AWS CLI installed: $AWS_VERSION"
else
    echo "   ❌ AWS CLI not installed"
    exit 1
fi
echo ""

# 2. Check AWS credentials
echo "2. Checking AWS credentials..."
if aws sts get-caller-identity &> /dev/null; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
    echo "   ✅ Credentials configured"
    echo "   Account ID: $ACCOUNT_ID"
    echo "   User ARN: $USER_ARN"
else
    echo "   ❌ AWS credentials not configured"
    exit 1
fi
echo ""

# 3. Check region configuration
echo "3. Checking region configuration..."
REGION=$(aws configure get region)
if [ -n "$REGION" ]; then
    echo "   ✅ Default region: $REGION"
else
    echo "   ⚠️  No default region set"
fi
echo ""

# 4. Check Terraform installation
echo "4. Checking Terraform installation..."
if command -v terraform &> /dev/null; then
    TF_VERSION=$(terraform version | head -n 1)
    echo "   ✅ Terraform installed: $TF_VERSION"
else
    echo "   ❌ Terraform not installed"
    exit 1
fi
echo ""

# 5. Test AWS API access
echo "5. Testing AWS API access..."
if aws ec2 describe-regions --region us-east-1 &> /dev/null; then
    echo "   ✅ Can access AWS EC2 API"
else
    echo "   ❌ Cannot access AWS API - check permissions"
    exit 1
fi
echo ""

# 6. Check IAM user details
echo "6. Checking IAM user details..."
USER_NAME=$(aws iam get-user --query User.UserName --output text 2>/dev/null || echo "Unable to retrieve")
if [ "$USER_NAME" != "Unable to retrieve" ]; then
    echo "   ✅ IAM User: $USER_NAME"
    
    # Check for MFA
    MFA=$(aws iam list-mfa-devices --user-name "$USER_NAME" --query 'MFADevices[0].SerialNumber' --output text 2>/dev/null || echo "None")
    if [ "$MFA" != "None" ]; then
        echo "   ✅ MFA enabled: $MFA"
    else
        echo "   ⚠️  MFA not enabled (recommended for security)"
    fi
else
    echo "   ⚠️  Cannot retrieve user details (might need iam:GetUser permission)"
fi
echo ""

# 7. Check billing alerts
echo "7. Checking billing alarm..."
ALARM_COUNT=$(aws cloudwatch describe-alarms --region us-east-1 --query 'MetricAlarms[?MetricName==`EstimatedCharges`] | length(@)' --output text 2>/dev/null || echo "0")
if [ "$ALARM_COUNT" -gt 0 ]; then
    echo "   ✅ Billing alarm(s) configured: $ALARM_COUNT"
else
    echo "   ⚠️  No billing alarms found (recommended for cost control)"
fi
echo ""

# 8. Summary
echo "═══════════════════════════════════════════════════════"
echo "✅ AWS SETUP VERIFICATION COMPLETE"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "You're ready to start provisioning infrastructure with Terraform!"
echo ""
