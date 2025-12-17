#!/bin/bash
# Calculate current AWS costs and credit usage

set -e

echo "💰 AWS Cost Calculator"
echo "====================="
echo ""

# Check AWS CLI
if ! aws sts get-caller-identity &>/dev/null; then
    echo "❌ AWS CLI not configured"
    exit 1
fi

AWS_REGION=$(aws configure get region)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Account ID: $ACCOUNT_ID"
echo "Region: $AWS_REGION"
echo ""

# Get current month's costs
START_DATE=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d)
END_DATE=$(date +%Y-%m-%d)

echo "📊 Current Month Costs ($START_DATE to $END_DATE):"
echo ""

TOTAL_COST=$(aws ce get-cost-and-usage \
    --time-period Start=$START_DATE,End=$END_DATE \
    --granularity MONTHLY \
    --metrics "UnblendedCost" \
    --query 'ResultsByTime[0].Total.UnblendedCost.Amount' \
    --output text 2>/dev/null || echo "0")

echo "Total Cost: \$$TOTAL_COST"
echo ""

# Calculate credit usage
CREDITS_TOTAL=200
CREDITS_USED=$(echo "$TOTAL_COST" | awk '{printf "%.2f", $1}')
CREDITS_REMAINING=$(echo "$CREDITS_TOTAL - $CREDITS_USED" | bc)
PERCENT_USED=$(echo "scale=2; ($CREDITS_USED / $CREDITS_TOTAL) * 100" | bc)

echo "💳 Credit Status:"
echo "   Total Credits: \$$CREDITS_TOTAL"
echo "   Credits Used: \$$CREDITS_USED"
echo "   Credits Remaining: \$$CREDITS_REMAINING"
echo "   Percentage Used: ${PERCENT_USED}%"
echo ""

# Warning thresholds
if (( $(echo "$PERCENT_USED > 90" | bc -l) )); then
    echo "🚨 WARNING: Over 90% of credits used! Consider shutting down resources."
elif (( $(echo "$PERCENT_USED > 75" | bc -l) )); then
    echo "⚠️  CAUTION: Over 75% of credits used."
elif (( $(echo "$PERCENT_USED > 50" | bc -l) )); then
    echo "ℹ️  INFO: Over 50% of credits used."
else
    echo "✅ Credit usage is healthy"
fi
