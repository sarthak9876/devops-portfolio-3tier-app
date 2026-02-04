#!/usr/bin/env bash

# ═══════════════════════════════════════════════════════════════════════════
# TaskMaster DevOps Portfolio - Workstation Bootstrap Script
# ═══════════════════════════════════════════════════════════════════════════
# Purpose: Install ALL dependencies required for the project
# Author: Sarthak Vaish (Senior DevOps Engineer)
# Usage: ./scripts/bootstrap/setup-workstation.sh
# Tested: Ubuntu 22.04/24.04, Amazon Linux 2023
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly LOG_DIR="${PROJECT_ROOT}/logs"
readonly LOG_FILE="${LOG_DIR}/bootstrap-$(date +%Y%m%d-%H%M%S).log"

# Versions (update these as needed)
readonly KUBECTL_VERSION="1.30.0"
readonly HELM_VERSION="3.14.0"
readonly TERRAFORM_VERSION="1.14.4"
readonly NODE_VERSION="20"
readonly DOCKER_COMPOSE_VERSION="2.24.5"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# ═══════════════════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $*" | tee -a "${LOG_FILE}"
}

log_success() {
    echo -e "${GREEN}✅${NC} $*" | tee -a "${LOG_FILE}"
}

log_warning() {
    echo -e "${YELLOW}⚠️${NC} $*" | tee -a "${LOG_FILE}"
}

log_error() {
    echo -e "${RED}❌${NC} $*" | tee -a "${LOG_FILE}"
}

command_exists() {
    command -v "$1" &> /dev/null
}

check_internet() {
    log_info "Checking internet connectivity..."
    if ping -c 1 8.8.8.8 &> /dev/null; then
        log_success "Internet connection: OK"
        return 0
    else
        log_error "No internet connection detected"
        return 1
    fi
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS="${ID}"
        OS_VERSION="${VERSION_ID}"
        log_info "Detected OS: ${NAME} ${VERSION_ID}"
    else
        log_error "Cannot detect operating system"
        exit 1
    fi
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should NOT be run as root (sudo will be used when needed)"
        exit 1
    fi
    
    # Check sudo access
    if ! sudo -n true 2>/dev/null; then
        log_info "Testing sudo access (you may be prompted for password)..."
        if ! sudo true; then
            log_error "This script requires sudo privileges"
            exit 1
        fi
    fi
    log_success "Sudo access: OK"
    
    # Check disk space (need at least 10GB free)
    local free_space
    free_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ ${free_space} -lt 10 ]]; then
        log_warning "Low disk space: ${free_space}GB free (recommend 10GB+)"
    else
        log_success "Disk space: ${free_space}GB available"
    fi
    
    check_internet || exit 1
}

# ═══════════════════════════════════════════════════════════════════════════
# INSTALLATION FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════

install_system_packages() {
    log_info "Installing system packages..."
    
    local packages=(
        curl
        wget
        git
        jq
        unzip
        tar
        ca-certificates
        gnupg
        lsb-release
        software-properties-common
        apt-transport-https
        build-essential
        python3
        python3-pip
        tree
        htop
        net-tools
    )
    
    case "${OS}" in
        ubuntu|debian)
            sudo apt-get update -qq >> "${LOG_FILE}" 2>&1 || {
                log_error "apt-get update failed"
                return 1
            }
            
            for pkg in "${packages[@]}"; do
                if dpkg -l | grep -q "^ii  ${pkg}"; then
                    log_info "  ${pkg}: already installed"
                else
                    log_info "  Installing ${pkg}..."
                    if sudo apt-get install -y "${pkg}" >> "${LOG_FILE}" 2>&1; then
                        log_success "  ${pkg}: installed"
                    else
                        log_error "  ${pkg}: installation failed"
                        return 1
                    fi
                fi
            done
            ;;
            
        amzn|rhel|centos)
            sudo yum update -y -q >> "${LOG_FILE}" 2>&1 || {
                log_error "yum update failed"
                return 1
            }
            
            # Map Ubuntu package names to RHEL equivalents
            local rhel_packages=(
                curl wget git jq unzip tar ca-certificates
                gnupg lsb_release python3 python3-pip
                tree htop net-tools gcc make
            )
            
            for pkg in "${rhel_packages[@]}"; do
                log_info "  Installing ${pkg}..."
                if sudo yum install -y "${pkg}" >> "${LOG_FILE}" 2>&1; then
                    log_success "  ${pkg}: installed"
                else
                    log_warning "  ${pkg}: installation failed (may not be critical)"
                fi
            done
            ;;
            
        *)
            log_error "Unsupported OS: ${OS}"
            return 1
            ;;
    esac
    
    log_success "System packages installed"
}

install_docker() {
    log_info "Installing Docker..."
    
    if command_exists docker; then
        local docker_version
        docker_version=$(docker --version | awk '{print $3}' | tr -d ',')
        log_info "Docker already installed: ${docker_version}"
        
        # Check if user is in docker group
        if groups | grep -q docker; then
            log_success "User already in docker group"
        else
            log_warning "Adding user to docker group..."
            sudo usermod -aG docker "${USER}"
            log_warning "⚠️  You need to LOG OUT and LOG IN again for docker group to take effect"
        fi
        return 0
    fi
    
    case "${OS}" in
        ubuntu|debian)
            # Remove old versions
            sudo apt-get remove -y docker docker-engine docker.io containerd runc >> "${LOG_FILE}" 2>&1 || true
            
            # Add Docker's official GPG key
            sudo install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
                sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg >> "${LOG_FILE}" 2>&1
            sudo chmod a+r /etc/apt/keyrings/docker.gpg
            
            # Set up repository
            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
                $(lsb_release -cs) stable" | \
                sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # Install Docker Engine
            sudo apt-get update -qq >> "${LOG_FILE}" 2>&1
            if sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >> "${LOG_FILE}" 2>&1; then
                log_success "Docker installed successfully"
            else
                log_error "Docker installation failed"
                return 1
            fi
            ;;
            
        amzn)
            sudo yum install -y docker >> "${LOG_FILE}" 2>&1
            sudo systemctl start docker
            sudo systemctl enable docker
            log_success "Docker installed successfully"
            ;;
    esac
    
    # Add user to docker group
    sudo usermod -aG docker "${USER}"
    
    # Start Docker service
    sudo systemctl start docker
    sudo systemctl enable docker
    
    log_success "Docker installed (version: $(docker --version | awk '{print $3}' | tr -d ','))"
    log_warning "⚠️  IMPORTANT: Log out and log back in for docker group permissions to take effect!"
}

install_docker_compose() {
    log_info "Installing Docker Compose..."
    
    if command_exists docker-compose; then
        log_info "Docker Compose already installed: $(docker-compose --version)"
        return 0
    fi
    
    # Docker Compose v2 comes as a plugin with Docker, but install standalone v2 as well
    local compose_url="https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64"
    
    if sudo curl -SL "${compose_url}" -o /usr/local/bin/docker-compose >> "${LOG_FILE}" 2>&1; then
        sudo chmod +x /usr/local/bin/docker-compose
        log_success "Docker Compose installed: $(docker-compose --version)"
    else
        log_error "Docker Compose installation failed"
        return 1
    fi
}

install_aws_cli() {
    log_info "Installing AWS CLI v2..."
    
    if command_exists aws; then
        local aws_version
        aws_version=$(aws --version | awk '{print $1}' | cut -d'/' -f2)
        log_info "AWS CLI already installed: ${aws_version}"
        return 0
    fi
    
    local temp_dir
    temp_dir=$(mktemp -d)
    cd "${temp_dir}"
    
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" >> "${LOG_FILE}" 2>&1
    unzip -q awscliv2.zip >> "${LOG_FILE}" 2>&1
    
    if sudo ./aws/install >> "${LOG_FILE}" 2>&1; then
        log_success "AWS CLI installed: $(aws --version)"
    else
        log_error "AWS CLI installation failed"
        cd - > /dev/null
        return 1
    fi
    
    cd - > /dev/null
    rm -rf "${temp_dir}"
}

install_kubectl() {
    log_info "Installing kubectl ${KUBECTL_VERSION}..."
    
    if command_exists kubectl; then
        local kubectl_version
        kubectl_version=$(kubectl version --client --short 2>/dev/null | awk '{print $3}')
        log_info "kubectl already installed: ${kubectl_version}"
        return 0
    fi
    
    local kubectl_url="https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    
    if curl -fsSL "${kubectl_url}" -o /tmp/kubectl >> "${LOG_FILE}" 2>&1; then
        chmod +x /tmp/kubectl
        sudo mv /tmp/kubectl /usr/local/bin/kubectl
        log_success "kubectl installed: $(kubectl version --client --short 2>/dev/null)"
    else
        log_error "kubectl installation failed"
        return 1
    fi
    
    # Enable kubectl autocompletion
    if [[ -f ~/.bashrc ]]; then
        if ! grep -q "kubectl completion bash" ~/.bashrc; then
            echo "" >> ~/.bashrc
            echo "# kubectl autocompletion" >> ~/.bashrc
            echo "source <(kubectl completion bash)" >> ~/.bashrc
            echo "alias k=kubectl" >> ~/.bashrc
            echo "complete -o default -F __start_kubectl k" >> ~/.bashrc
            log_info "kubectl autocompletion added to ~/.bashrc"
        fi
    fi
}

install_helm() {
    log_info "Installing Helm ${HELM_VERSION}..."
    
    if command_exists helm; then
        local helm_version
        helm_version=$(helm version --short | awk '{print $1}')
        log_info "Helm already installed: ${helm_version}"
        return 0
    fi
    
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | \
        bash -s -- --version "v${HELM_VERSION}" >> "${LOG_FILE}" 2>&1
    
    if command_exists helm; then
        log_success "Helm installed: $(helm version --short)"
    else
        log_error "Helm installation failed"
        return 1
    fi
    
    # Enable Helm autocompletion
    if [[ -f ~/.bashrc ]]; then
        if ! grep -q "helm completion bash" ~/.bashrc; then
            echo "" >> ~/.bashrc
            echo "# Helm autocompletion" >> ~/.bashrc
            echo "source <(helm completion bash)" >> ~/.bashrc
            log_info "Helm autocompletion added to ~/.bashrc"
        fi
    fi
}

install_terraform() {
    log_info "Installing Terraform ${TERRAFORM_VERSION}..."
    
    if command_exists terraform; then
        local tf_version
        tf_version=$(terraform version | head -1 | awk '{print $2}')
        log_info "Terraform already installed: ${tf_version}"
        return 0
    fi
    
    local temp_dir
    temp_dir=$(mktemp -d)
    cd "${temp_dir}"
    
    local tf_url="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
    
    if curl -fsSL "${tf_url}" -o terraform.zip >> "${LOG_FILE}" 2>&1; then
        unzip -q terraform.zip >> "${LOG_FILE}" 2>&1
        chmod +x terraform
        sudo mv terraform /usr/local/bin/
        log_success "Terraform installed: $(terraform version | head -1)"
    else
        log_error "Terraform installation failed"
        cd - > /dev/null
        return 1
    fi
    
    cd - > /dev/null
    rm -rf "${temp_dir}"
}

install_node() {
    log_info "Installing Node.js ${NODE_VERSION}..."
    
    if command_exists node; then
        local node_version
        node_version=$(node --version)
        log_info "Node.js already installed: ${node_version}"
        return 0
    fi
    
    # Install Node.js via NodeSource
    curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | sudo -E bash - >> "${LOG_FILE}" 2>&1
    
    case "${OS}" in
        ubuntu|debian)
            if sudo apt-get install -y nodejs >> "${LOG_FILE}" 2>&1; then
                log_success "Node.js installed: $(node --version)"
                log_info "npm version: $(npm --version)"
            else
                log_error "Node.js installation failed"
                return 1
            fi
            ;;
        amzn|rhel|centos)
            if sudo yum install -y nodejs >> "${LOG_FILE}" 2>&1; then
                log_success "Node.js installed: $(node --version)"
            else
                log_error "Node.js installation failed"
                return 1
            fi
            ;;
    esac
}

install_additional_tools() {
    log_info "Installing additional DevOps tools..."
    
    # k9s (Kubernetes CLI UI)
    if ! command_exists k9s; then
        log_info "  Installing k9s..."
        local k9s_url="https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz"
        local temp_dir
        temp_dir=$(mktemp -d)
        
        if curl -fsSL "${k9s_url}" | tar xz -C "${temp_dir}" >> "${LOG_FILE}" 2>&1; then
            sudo mv "${temp_dir}/k9s" /usr/local/bin/
            log_success "  k9s installed"
        else
            log_warning "  k9s installation failed (optional tool)"
        fi
        rm -rf "${temp_dir}"
    fi
    
    # kubectx/kubens (context switcher)
    if ! command_exists kubectx; then
        log_info "  Installing kubectx/kubens..."
        sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx >> "${LOG_FILE}" 2>&1
        sudo ln -sf /opt/kubectx/kubectx /usr/local/bin/kubectx
        sudo ln -sf /opt/kubectx/kubens /usr/local/bin/kubens
        log_success "  kubectx/kubens installed"
    fi
    
    # stern (multi-pod log tailing)
    if ! command_exists stern; then
        log_info "  Installing stern..."
        local stern_version="1.28.0"
        local stern_url="https://github.com/stern/stern/releases/download/v${stern_version}/stern_${stern_version}_linux_amd64.tar.gz"
        local temp_dir
        temp_dir=$(mktemp -d)
        
        if curl -fsSL "${stern_url}" | tar xz -C "${temp_dir}" >> "${LOG_FILE}" 2>&1; then
            sudo mv "${temp_dir}/stern" /usr/local/bin/
            log_success "  stern installed"
        else
            log_warning "  stern installation failed (optional tool)"
        fi
        rm -rf "${temp_dir}"
    fi
    
    # yq (YAML processor)
    if ! command_exists yq; then
        log_info "  Installing yq..."
        local yq_version="4.40.5"
        local yq_url="https://github.com/mikefarah/yq/releases/download/v${yq_version}/yq_linux_amd64"
        
        if sudo curl -fsSL "${yq_url}" -o /usr/local/bin/yq >> "${LOG_FILE}" 2>&1; then
            sudo chmod +x /usr/local/bin/yq
            log_success "  yq installed"
        else
            log_warning "  yq installation failed (optional tool)"
        fi
    fi
}

configure_git() {
    log_info "Configuring Git..."
    
    if [[ -z "$(git config --global user.name)" ]]; then
        read -rp "Enter your Git username: " git_username
        git config --global user.name "${git_username}"
        log_success "Git username set: ${git_username}"
    else
        log_info "Git username already set: $(git config --global user.name)"
    fi
    
    if [[ -z "$(git config --global user.email)" ]]; then
        read -rp "Enter your Git email: " git_email
        git config --global user.email "${git_email}"
        log_success "Git email set: ${git_email}"
    else
        log_info "Git email already set: $(git config --global user.email)"
    fi
    
    # Set useful Git aliases
    git config --global alias.st status
    git config --global alias.co checkout
    git config --global alias.br branch
    git config --global alias.ci commit
    git config --global alias.unstage 'reset HEAD --'
    git config --global alias.last 'log -1 HEAD'
    
    log_success "Git aliases configured"
}

generate_ssh_key() {
    log_info "Checking SSH keys..."
    
    if [[ -f ~/.ssh/id_rsa ]]; then
        log_info "SSH key already exists: ~/.ssh/id_rsa"
        return 0
    fi
    
    read -rp "Generate SSH key? (y/n): " generate_key
    if [[ "${generate_key}" == "y" ]]; then
        read -rp "Enter your email for SSH key: " ssh_email
        ssh-keygen -t rsa -b 4096 -C "${ssh_email}" -f ~/.ssh/id_rsa -N "" >> "${LOG_FILE}" 2>&1
        log_success "SSH key generated: ~/.ssh/id_rsa.pub"
        
        echo ""
        log_warning "Add this SSH key to your GitHub account:"
        cat ~/.ssh/id_rsa.pub
        echo ""
    fi
}

verify_installation() {
    log_info "Verifying installations..."
    
    local tools=(
        "docker:Docker"
        "docker-compose:Docker Compose"
        "aws:AWS CLI"
        "kubectl:kubectl"
        "helm:Helm"
        "terraform:Terraform"
        "node:Node.js"
        "npm:npm"
        "git:Git"
        "jq:jq"
    )
    
    local failed=0
    
    for tool_pair in "${tools[@]}"; do
        IFS=':' read -r cmd name <<< "${tool_pair}"
        if command_exists "${cmd}"; then
            log_success "  ${name}: $(${cmd} --version 2>&1 | head -1)"
        else
            log_error "  ${name}: NOT FOUND"
            ((failed++))
        fi
    done
    
    if [[ ${failed} -gt 0 ]]; then
        log_error "${failed} tool(s) failed to install"
        return 1
    else
        log_success "All tools installed successfully"
        return 0
    fi
}

print_next_steps() {
    cat << 'NEXT_STEPS'

═══════════════════════════════════════════════════════════════════════════
🎉 BOOTSTRAP COMPLETE!
═══════════════════════════════════════════════════════════════════════════

📋 NEXT STEPS:

1. LOG OUT AND LOG BACK IN (required for Docker group permissions)
   
2. Configure AWS credentials:
   aws configure
   # Enter: Access Key, Secret Key, Region (us-east-1), Output format (json)

3. Test AWS access:
   aws sts get-caller-identity

4. Navigate to project:
   cd ~/devops-portfolio-3tier-app

5. Initialize Terraform:
   cd terraform/environments/dev
   terraform init

6. Deploy infrastructure:
   terraform plan
   terraform apply

7. Configure kubectl:
   aws eks update-kubeconfig --region us-east-1 --name taskmaster-dev-cluster

8. Verify cluster access:
   kubectl get nodes

═══════════════════════════════════════════════════════════════════════════
📚 USEFUL COMMANDS:

  kubectl get pods -A              # List all pods
  kubectl get nodes -o wide        # List nodes with details
  helm list -A                     # List all Helm releases
  k9s                              # Interactive cluster UI
  stern <pod-name>                 # Tail logs from multiple pods
  kubectx                          # Switch Kubernetes contexts
  kubens                           # Switch namespaces

═══════════════════════════════════════════════════════════════════════════
📁 LOG FILE: Check installation details at:
   ${LOG_FILE}

═══════════════════════════════════════════════════════════════════════════
NEXT_STEPS
}

# ═══════════════════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════════════════════

main() {
    # Create log directory
    mkdir -p "${LOG_DIR}"
    
    # Header
    cat << 'HEADER'
═══════════════════════════════════════════════════════════════════════════
  TaskMaster DevOps Portfolio - Workstation Bootstrap
  Installing: Docker, AWS CLI, kubectl, Helm, Terraform, Node.js, and more
═══════════════════════════════════════════════════════════════════════════
HEADER
    
    log_info "Starting bootstrap at $(date)"
    log_info "Log file: ${LOG_FILE}"
    echo ""
    
    # Pre-flight checks
    detect_os
    check_prerequisites
    echo ""
    
    # Core installations (will fail script if any fails)
    install_system_packages || exit 1
    install_docker || exit 1
    install_docker_compose || exit 1
    install_aws_cli || exit 1
    install_kubectl || exit 1
    install_helm || exit 1
    install_terraform || exit 1
    install_node || exit 1
    
    # Optional tools (failures won't stop script)
    install_additional_tools
    
    # Configuration
    configure_git
    generate_ssh_key
    
    echo ""
    
    # Verification
    verify_installation || {
        log_error "Some installations failed. Check log: ${LOG_FILE}"
        exit 1
    }
    
    echo ""
    print_next_steps
    
    log_info "Bootstrap completed successfully at $(date)"
}

# Run main function
main "$@"
