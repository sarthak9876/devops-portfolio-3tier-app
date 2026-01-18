#!/bin/bash
# Fix Frontend-Backend Connection Script
# This script rebuilds and redeploys the frontend with API proxy configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Fixing Frontend-Backend Connection${NC}"
echo "=============================================="

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}❌ Error: Please run this script from the devops-portfolio-3tier-app directory${NC}"
    exit 1
fi

# Get AWS Account ID
echo -e "${YELLOW}🔍 Getting AWS Account ID...${NC}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if [ -z "$ACCOUNT_ID" ]; then
    echo -e "${RED}❌ Error: Could not get AWS Account ID. Make sure AWS CLI is configured.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Account ID: ${ACCOUNT_ID}${NC}"

# Build and push frontend image
echo -e "${YELLOW}🏗️  Building frontend Docker image...${NC}"
cd application/frontend
docker build -t taskmaster-frontend:latest .
docker tag taskmaster-frontend:latest ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/taskmaster-frontend:latest

echo -e "${YELLOW}📤 Pushing frontend image to ECR...${NC}"
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com
docker push ${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/taskmaster-frontend:latest
cd ../..

echo -e "${GREEN}✅ Frontend image updated!${NC}"

# Update Kubernetes manifests with Account ID
echo -e "${YELLOW}📝 Updating Kubernetes manifests...${NC}"
cd kubernetes/manifests
sed -i.bak "s/\${ACCOUNT_ID}/${ACCOUNT_ID}/g" *.yml
cd ../..

# Deploy to Kubernetes
echo -e "${YELLOW}🚀 Deploying to Kubernetes...${NC}"
cd kubernetes
./deploy.sh
cd ..

echo ""
echo -e "${GREEN}🎉 Frontend-Backend Connection Fixed!${NC}"
echo "=============================================="
echo ""
echo "📋 What was changed:"
echo "   ✅ Added nginx proxy configuration for /api/* requests"
echo "   ✅ Frontend now proxies API calls to backend-service internally"
echo "   ✅ No external backend LoadBalancer needed"
echo ""
echo "🌐 Your application should now work at the frontend LoadBalancer URL"
echo "   The frontend will show 'Backend: Online' and 'Database: Connected'"
echo ""
echo -e "${YELLOW}⚠️  Note: Make sure your backend and database are running properly${NC}"

