#!/bin/bash
# Comprehensive environment validation before cloud deployment
# Prevents costly mistakes and ensures all prerequisites are met

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

echo "🔍 DevOps Portfolio Project - Environment Validation"
echo "===================================================="
echo ""

# Function to check command existence
check_command() {
    local cmd=$1
    local required_version=$2
    
    if command -v $cmd &> /dev/null; then
        local version=$(eval "$cmd --version 2>&1 | head -n 1")
        echo -e "${GREEN}✅ $cmd${NC}: $version"
        return 0
    else
        echo -e "${RED}❌ $cmd${NC}: NOT INSTALLED"
        echo "   Install: $3"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

# 1. Check Required Tools
echo "1️⃣  Checking Required CLI Tools..."
echo "--------------------------------"
check_command "aws" "" "curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o awscliv2.zip && unzip awscliv2.zip && sudo ./aws/install"
check_command "docker" "" "https://docs.docker.com/get-docker/"
check_command "kubectl" "" "curl -LO https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
check_command "terraform" "" "https://www.terraform.io/downloads"
check_command "ansible" "" "sudo apt-get install ansible -y"
check_command "git" "" "sudo apt-get install git -y"
check_command "minikube" "" "curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64"
echo ""

# 2. Check AWS Configuration
echo "2️⃣  Checking AWS Configuration..."
echo "--------------------------------"
if aws sts get-caller-identity &>/dev/null; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    AWS_USER=$(aws sts get-caller-identity --query Arn --output text)
    AWS_REGION=$(aws configure get region)
    
    echo -e "${GREEN}✅ AWS CLI Configured${NC}"
    echo "   Account ID: $ACCOUNT_ID"
    echo "   User: $AWS_USER"
    echo "   Region: $AWS_REGION"
    
    # Check if region is free-tier friendly
    if [ "$AWS_REGION" == "us-east-1" ] || [ "$AWS_REGION" == "us-west-2" ]; then
        echo -e "${GREEN}   ✅ Region is free-tier friendly${NC}"
    else
        echo -e "${YELLOW}   ⚠️  Region may have limited free tier availability${NC}"
        echo "   Consider using us-east-1 or us-west-2"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo -e "${RED}❌ AWS CLI Not Configured${NC}"
    echo "   Run: aws configure"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# 3. Check Docker Status
echo "3️⃣  Checking Docker Service..."
echo "----------------------------"
if docker ps &>/dev/null; then
    echo -e "${GREEN}✅ Docker daemon running${NC}"
    DOCKER_VERSION=$(docker version --format '{{.Server.Version}}')
    echo "   Docker version: $DOCKER_VERSION"
else
    echo -e "${RED}❌ Docker daemon not running${NC}"
    echo "   Run: sudo systemctl start docker"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# 4. Check System Resources
echo "4️⃣  Checking System Resources..."
echo "------------------------------"

# Check available memory
TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
if [ $TOTAL_MEM -ge 8 ]; then
    echo -e "${GREEN}✅ Memory: ${TOTAL_MEM}GB${NC} (sufficient)"
else
    echo -e "${YELLOW}⚠️  Memory: ${TOTAL_MEM}GB${NC} (8GB+ recommended)"
    WARNINGS=$((WARNINGS + 1))
fi

# Check available disk space
DISK_AVAIL=$(df -h . | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "${DISK_AVAIL%%.*}" -ge 50 ]; then
    echo -e "${GREEN}✅ Disk Space: ${DISK_AVAIL}GB available${NC} (sufficient)"
else
    echo -e "${YELLOW}⚠️  Disk Space: ${DISK_AVAIL}GB available${NC} (50GB+ recommended)"
    WARNINGS=$((WARNINGS + 1))
fi

# Check CPU cores
CPU_CORES=$(nproc)
if [ $CPU_CORES -ge 2 ]; then
    echo -e "${GREEN}✅ CPU Cores: $CPU_CORES${NC} (sufficient)"
else
    echo -e "${YELLOW}⚠️  CPU Cores: $CPU_CORES${NC} (2+ recommended)"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# 5. Check Minikube Status
echo "5️⃣  Checking Minikube..."
echo "----------------------"
if minikube status &>/dev/null; then
    echo -e "${GREEN}✅ Minikube is running${NC}"
    kubectl get nodes 2>/dev/null || true
else
    echo -e "${YELLOW}ℹ️  Minikube not started${NC}"
    echo "   (This is OK - start when needed with: minikube start)"
fi
echo ""

# 6. Check GitHub Configuration
echo "6️⃣  Checking Git Configuration..."
echo "-------------------------------"
if git config user.name &>/dev/null && git config user.email &>/dev/null; then
    GIT_USER=$(git config user.name)
    GIT_EMAIL=$(git config user.email)
    echo -e "${GREEN}✅ Git configured${NC}"
    echo "   Name: $GIT_USER"
    echo "   Email: $GIT_EMAIL"
else
    echo -e "${RED}❌ Git not configured${NC}"
    echo "   Run: git config --global user.name 'Your Name'"
    echo "   Run: git config --global user.email 'your.email@example.com'"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# 7. Check AWS Free Tier Eligibility
echo "7️⃣  Checking AWS Free Tier Status..."
echo "-----------------------------------"
echo "⚠️  Manual verification required:"
echo "   1. Go to: https://console.aws.amazon.com/billing/home#/credits"
echo "   2. Verify you have ~\$200 in credits"
echo "   3. Check account creation date (should be after July 15, 2025)"
echo ""

# 8. Check Billing Alarms
echo "8️⃣  Checking Billing Alarms..."
echo "-----------------------------"
ALARM_COUNT=$(aws cloudwatch describe-alarms --region us-east-1 --query 'MetricAlarms[?Namespace==`AWS/Billing`] | length(@)' --output text 2>/dev/null || echo "0")

if [ "$ALARM_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✅ Billing alarms configured: $ALARM_COUNT alarm(s)${NC}"
else
    echo -e "${RED}❌ No billing alarms configured${NC}"
    echo "   ⚠️  CRITICAL: Set up billing alarms first!"
    echo "   Go to Step 0.1 and configure CloudWatch billing alarms"
    ERRORS=$((ERRORS + 1))
fi
echo ""

# Summary
echo "=========================================="
echo "📊 VALIDATION SUMMARY"
echo "=========================================="
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✅ ALL CHECKS PASSED!${NC}"
    echo ""
    echo "🚀 You're ready to start building infrastructure!"
    echo ""
    echo "Next steps:"
    echo "   1. Review Phase 1: Application Selection"
    echo "   2. Run cost calculator: ./scripts/cost-calculator.sh"
    echo "   3. Start with Terraform infrastructure setup"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠️  PASSED WITH ${WARNINGS} WARNING(S)${NC}"
    echo ""
    echo "You can proceed, but consider addressing warnings for optimal experience."
    exit 0
else
    echo -e "${RED}❌ VALIDATION FAILED${NC}"
    echo ""
    echo "Errors: $ERRORS"
    echo "Warnings: $WARNINGS"
    echo ""
    echo "Please fix all errors before proceeding to cloud deployment."
    exit 1
fi
