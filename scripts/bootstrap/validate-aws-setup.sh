#!/usr/bin/env bash

# ═══════════════════════════════════════════════════════════════════════════
# AWS Setup Validator
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

log_success() { echo -e "${GREEN}✅${NC} $*"; }
log_error() { echo -e "${RED}❌${NC} $*"; }
log_warning() { echo -e "${YELLOW}⚠️${NC} $*"; }
log_info() { echo -e "${NC}ℹ️${NC} $*"; }

echo "═══════════════════════════════════════════════════════════════"
echo "  AWS Configuration Validator"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI not installed"
    exit 1
fi
log_success "AWS CLI installed: $(aws --version)"

# Check credentials
if [[ ! -f ~/.aws/credentials ]]; then
    log_error "AWS credentials not configured"
    echo ""
    echo "Run: aws configure"
    exit 1
fi
log_success "AWS credentials file exists"

# Validate credentials work
echo ""
log_info "Testing AWS credentials..."
if IDENTITY=$(aws sts get-caller-identity 2>&1); then
    log_success "AWS credentials are valid"
    echo "${IDENTITY}" | jq .
else
    log_error "AWS credentials invalid or expired"
    echo "${IDENTITY}"
    exit 1
fi

# Check region
echo ""
AWS_REGION=$(aws configure get region)
if [[ "${AWS_REGION}" == "us-east-1" ]]; then
    log_success "AWS region: ${AWS_REGION} ✅"
else
    log_warning "AWS region: ${AWS_REGION} (expected us-east-1)"
fi

# Check permissions (EKS, EC2, VPC)
echo ""
log_info "Checking AWS permissions..."

check_permission() {
    local service="$1"
    local action="$2"
    
    if aws ${service} ${action} --region us-east-1 &> /dev/null; then
        log_success "  ${service} ${action}: OK"
    else
        log_error "  ${service} ${action}: FAILED"
        return 1
    fi
}

check_permission "ec2" "describe-vpcs" || true
check_permission "eks" "list-clusters" || true
check_permission "iam" "list-roles" || true
check_permission "ecr" "describe-repositories" || true

echo ""
log_success "AWS setup validation complete"
