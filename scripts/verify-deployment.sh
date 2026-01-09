#!/bin/bash
# ═══════════════════════════════════════════════════════
# Deployment Verification Script
# Tests all components of TaskMaster deployment
# ═══════════════════════════════════════════════════════

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "════════════════════════════════════════════════════════"
echo "TaskMaster Deployment Verification"
echo "════════════════════════════════════════════════════════"
echo ""

# Get outputs from Terraform
cd terraform/environments/dev

if [ ! -f "terraform.tfstate" ]; then
    echo -e "${RED}❌ Terraform state not found. Run 'terraform apply' first.${NC}"
    exit 1
fi

INSTANCE_ID=$(terraform output -raw instance_id)
PUBLIC_IP=$(terraform output -raw instance_public_ip)
FRONTEND_URL=$(terraform output -raw frontend_url)
BACKEND_URL=$(terraform output -raw backend_url)

echo "Instance ID: $INSTANCE_ID"
echo "Public IP: $PUBLIC_IP"
echo ""

# Test 1: EC2 Instance Running
echo "1. Checking EC2 instance status..."
STATE=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0].State.Name' --output text)
if [ "$STATE" == "running" ]; then
    echo -e "   ${GREEN}✅ EC2 instance is running${NC}"
else
    echo -e "   ${RED}❌ EC2 instance is $STATE${NC}"
    exit 1
fi
echo ""

# Test 2: SSH Connectivity
echo "2. Testing SSH connectivity..."
if ssh -i ~/.ssh/taskmaster-dev -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@"$PUBLIC_IP" "echo 'SSH OK'" &>/dev/null; then
    echo -e "   ${GREEN}✅ SSH connection successful${NC}"
else
    echo -e "   ${RED}❌ SSH connection failed${NC}"
    exit 1
fi
echo ""

# Test 3: Docker Installation
echo "3. Checking Docker installation..."
DOCKER_VERSION=$(ssh -i ~/.ssh/taskmaster-dev ubuntu@"$PUBLIC_IP" "docker --version" 2>/dev/null)
if [ $? -eq 0 ]; then
    echo -e "   ${GREEN}✅ Docker installed: $DOCKER_VERSION${NC}"
else
    echo -e "   ${RED}❌ Docker not installed${NC}"
    exit 1
fi
echo ""

# Test 4: Docker Compose Running
echo "4. Checking Docker Compose containers..."
CONTAINER_COUNT=$(ssh -i ~/.ssh/taskmaster-dev ubuntu@"$PUBLIC_IP" "cd devops-portfolio-3tier-app && docker compose ps -q | wc -l" 2>/dev/null)
if [ "$CONTAINER_COUNT" -ge 3 ]; then
    echo -e "   ${GREEN}✅ Docker Compose running ($CONTAINER_COUNT containers)${NC}"
    ssh -i ~/.ssh/taskmaster-dev ubuntu@"$PUBLIC_IP" "cd devops-portfolio-3tier-app && docker compose ps"
else
    echo -e "   ${YELLOW}⚠️  Expected 3 containers, found $CONTAINER_COUNT${NC}"
fi
echo ""

# Test 5: Backend Health Check
echo "5. Testing backend health endpoint..."
HEALTH=$(curl -s -o /dev/null -w "%{http_code}" "$BACKEND_URL/health")
if [ "$HEALTH" -eq 200 ]; then
    echo -e "   ${GREEN}✅ Backend health check passed${NC}"
    curl -s "$BACKEND_URL/health" | jq .
else
    echo -e "   ${RED}❌ Backend health check failed (HTTP $HEALTH)${NC}"
fi
echo ""

# Test 6: Backend API
echo "6. Testing backend API..."
API_RESPONSE=$(curl -s "$BACKEND_URL/api/tasks")
TASK_COUNT=$(echo "$API_RESPONSE" | jq '.data | length')
if [ $? -eq 0 ]; then
    echo -e "   ${GREEN}✅ Backend API working (found $TASK_COUNT tasks)${NC}"
else
    echo -e "   ${RED}❌ Backend API failed${NC}"
fi
echo ""

# Test 7: Frontend Accessibility
echo "7. Testing frontend accessibility..."
FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$FRONTEND_URL")
if [ "$FRONTEND_STATUS" -eq 200 ]; then
    echo -e "   ${GREEN}✅ Frontend accessible (HTTP $FRONTEND_STATUS)${NC}"
else
    echo -e "   ${RED}❌ Frontend not accessible (HTTP $FRONTEND_STATUS)${NC}"
fi
echo ""

# Summary
echo "════════════════════════════════════════════════════════"
echo -e "${GREEN}✅ DEPLOYMENT VERIFICATION COMPLETE${NC}"
echo "════════════════════════════════════════════════════════"
echo ""
echo "📊 Access URLs:"
echo "   Frontend: $FRONTEND_URL"
echo "   Backend:  $BACKEND_URL"
echo ""
echo "🔐 SSH Command:"
echo "   ssh -i ~/.ssh/taskmaster-dev ubuntu@$PUBLIC_IP"
echo ""
