#!/usr/bin/env bash

# ═══════════════════════════════════════════════════════════════════════════
# Project Prerequisites Checker
# Verifies all dependencies before deployment
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

log_success() { echo -e "${GREEN}✅${NC} $*"; }
log_error() { echo -e "${RED}❌${NC} $*"; }
log_warning() { echo -e "${YELLOW}⚠️${NC} $*"; }
log_info() { echo -e "ℹ️  $*"; }

FAILED=0

check_command() {
    local cmd="$1"
    local name="$2"
    local min_version="${3:-}"
    
    if command -v "${cmd}" &> /dev/null; then
        local version
        case "${cmd}" in
            docker)
                version=$(docker --version | awk '{print $3}' | tr -d ',')
                ;;
            kubectl)
                version=$(kubectl version --client 2>/dev/null | head -1 | awk '{print $3}')
                ;;
            helm)
                version=$(helm version --short | awk '{print $1}')
                ;;
            terraform)
                version=$(terraform version | head -1 | awk '{print $2}')
                ;;
            node)
                version=$(node --version)
                ;;
            aws)
                version=$(aws --version | awk '{print $1}' | cut -d'/' -f2)
                ;;
            *)
                version="installed"
                ;;
        esac
        
        log_success "${name}: ${version}"
    else
        log_error "${name}: NOT FOUND"
        ((FAILED++))
    fi
}

echo "═══════════════════════════════════════════════════════════════"
echo "  Prerequisites Checker"
echo "═══════════════════════════════════════════════════════════════"
echo ""

log_info "Checking required tools..."
echo ""

# Core tools
check_command "docker" "Docker"
check_command "docker-compose" "Docker Compose"
check_command "aws" "AWS CLI"
check_command "kubectl" "kubectl"
check_command "helm" "Helm"
check_command "terraform" "Terraform"
check_command "node" "Node.js"
check_command "npm" "npm"
check_command "git" "Git"
check_command "jq" "jq"
check_command "curl" "curl"

echo ""
log_info "Checking optional tools..."
echo ""

# Optional tools
check_command "k9s" "k9s (optional)" || log_info "  k9s not installed (optional)"
check_command "kubectx" "kubectx (optional)" || log_info "  kubectx not installed (optional)"
check_command "stern" "stern (optional)" || log_info "  stern not installed (optional)"
check_command "yq" "yq (optional)" || log_info "  yq not installed (optional)"

echo ""
log_info "Checking Docker daemon..."
if docker ps &> /dev/null; then
    log_success "Docker daemon: RUNNING"
else
    log_error "Docker daemon: NOT RUNNING"
    log_info "  Start with: sudo systemctl start docker"
    ((FAILED++))
fi

echo ""
log_info "Checking Docker permissions..."
if docker ps &> /dev/null; then
    log_success "Docker permissions: OK (no sudo required)"
else
    log_warning "Docker permissions: User not in docker group"
    log_info "  Add with: sudo usermod -aG docker \$USER"
    log_info "  Then logout and login again"
fi

echo ""
log_info "Checking AWS configuration..."
if [[ -f ~/.aws/credentials ]]; then
    log_success "AWS credentials: CONFIGURED"
    if aws sts get-caller-identity &> /dev/null; then
        log_success "AWS credentials: VALID"
    else
        log_error "AWS credentials: INVALID or EXPIRED"
        ((FAILED++))
    fi
else
    log_error "AWS credentials: NOT CONFIGURED"
    log_info "  Run: aws configure"
    ((FAILED++))
fi

echo ""
log_info "Checking Git configuration..."
if [[ -n "$(git config --global user.name)" ]]; then
    log_success "Git user.name: $(git config --global user.name)"
else
    log_warning "Git user.name: NOT SET"
    log_info "  Run: git config --global user.name 'Your Name'"
fi

if [[ -n "$(git config --global user.email)" ]]; then
    log_success "Git user.email: $(git config --global user.email)"
else
    log_warning "Git user.email: NOT SET"
    log_info "  Run: git config --global user.email 'your@email.com'"
fi

echo ""
log_info "Checking SSH keys..."
if [[ -f ~/.ssh/id_rsa ]]; then
    log_success "SSH key exists: ~/.ssh/id_rsa"
else
    log_warning "SSH key not found"
    log_info "  Generate with: ssh-keygen -t rsa -b 4096"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
if [[ ${FAILED} -eq 0 ]]; then
    log_success "ALL CHECKS PASSED! Ready to deploy."
    exit 0
else
    log_error "${FAILED} check(s) failed. Fix issues above before deploying."
    exit 1
fi
