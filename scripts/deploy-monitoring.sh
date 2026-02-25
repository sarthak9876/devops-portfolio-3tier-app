#!/bin/bash

#═══════════════════════════════════════════════════════════════════
# MONITORING STACK DEPLOYMENT AUTOMATION
# Production-grade deployment script for Prometheus + Grafana + EBS CSI
#═══════════════════════════════════════════════════════════════════
# Author: DevOps Mentor (10+ years experience)
# Purpose: Automate complete monitoring infrastructure setup
# Usage: ./deploy-monitoring-stack.sh
#═══════════════════════════════════════════════════════════════════

set -e  # Exit on any error
set -o pipefail  # Catch errors in pipelines

#═══════════════════════════════════════════════════════════════════
# CONFIGURATION VARIABLES
#═══════════════════════════════════════════════════════════════════

# Cluster configuration
CLUSTER_NAME="${CLUSTER_NAME:-taskmaster-dev-eks}"
AWS_REGION="${AWS_REGION:-us-east-1}"
NAMESPACE="monitoring"

# Helm configuration
HELM_RELEASE_NAME="monitoring"
HELM_CHART="prometheus-community/kube-prometheus-stack"
HELM_VALUES_FILE="values-monitoring.yml"

# EBS CSI configuration
EBS_CSI_DRIVER_VERSION="latest"
STORAGE_CLASS_NAME="gp3"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

#═══════════════════════════════════════════════════════════════════
# UTILITY FUNCTIONS
#═══════════════════════════════════════════════════════════════════

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_section() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Progress spinner
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Error handler
error_exit() {
    log_error "$1"
    log_error "Deployment failed! Check logs above for details."
    exit 1
}

# Command exists check
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Wait for condition with timeout
wait_for_condition() {
    local condition="$1"
    local description="$2"
    local timeout="${3:-300}"  # Default 5 minutes
    local interval=5
    local elapsed=0

    log_info "Waiting for: $description (timeout: ${timeout}s)"
    
    while ! eval "$condition" >/dev/null 2>&1; do
        if [ $elapsed -ge $timeout ]; then
            error_exit "Timeout waiting for: $description"
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
        echo -n "."
    done
    echo ""
    log_success "$description"
}

#═══════════════════════════════════════════════════════════════════
# PREREQUISITE CHECKS
#═══════════════════════════════════════════════════════════════════

check_prerequisites() {
    log_section "STEP 1: CHECKING PREREQUISITES"

    # Check required commands
    local required_commands=("kubectl" "helm" "aws" "eksctl" "jq")
    local missing_commands=()

    for cmd in "${required_commands[@]}"; do
        if command_exists "$cmd"; then
            local version=$($cmd version --short 2>/dev/null || $cmd version 2>/dev/null | head -1 || echo "unknown")
            log_success "$cmd is installed: $version"
        else
            log_error "$cmd is NOT installed"
            missing_commands+=("$cmd")
        fi
    done

    if [ ${#missing_commands[@]} -ne 0 ]; then
        log_error "Missing required commands: ${missing_commands[*]}"
        log_info "Install missing commands:"
        for cmd in "${missing_commands[@]}"; do
            case $cmd in
                kubectl)
                    echo "  kubectl: curl -LO \"https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl\" && sudo install kubectl /usr/local/bin/"
                    ;;
                helm)
                    echo "  helm: curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
                    ;;
                eksctl)
                    echo "  eksctl: curl --silent --location \"https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_\$(uname -s)_amd64.tar.gz\" | tar xz -C /tmp && sudo mv /tmp/eksctl /usr/local/bin"
                    ;;
                aws)
                    echo "  aws-cli: curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"awscliv2.zip\" && unzip awscliv2.zip && sudo ./aws/install"
                    ;;
                jq)
                    echo "  jq: sudo apt-get install jq -y"
                    ;;
            esac
        done
        exit 1
    fi

    # Check AWS credentials
    log_info "Checking AWS credentials..."
    if aws sts get-caller-identity >/dev/null 2>&1; then
        local account_id=$(aws sts get-caller-identity --query Account --output text)
        local user_arn=$(aws sts get-caller-identity --query Arn --output text)
        log_success "AWS credentials valid"
        log_info "  Account ID: $account_id"
        log_info "  User/Role: $user_arn"
    else
        error_exit "AWS credentials not configured or invalid. Run: aws configure"
    fi

    # Check kubectl context
    log_info "Checking kubectl context..."
    if kubectl cluster-info >/dev/null 2>&1; then
        local current_context=$(kubectl config current-context)
        log_success "kubectl connected to cluster"
        log_info "  Context: $current_context"
        
        # Verify it's the correct cluster
        if [[ ! "$current_context" =~ "$CLUSTER_NAME" ]]; then
            log_warn "Current context doesn't match CLUSTER_NAME ($CLUSTER_NAME)"
            log_warn "Current context: $current_context"
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    else
        error_exit "kubectl cannot connect to cluster. Run: aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION"
    fi

    # Check Helm repos
    log_info "Checking Helm repositories..."
    if helm repo list | grep -q "prometheus-community"; then
        log_success "prometheus-community repo already added"
    else
        log_info "Adding prometheus-community repo..."
        helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
        log_success "prometheus-community repo added"
    fi

    log_info "Updating Helm repos..."
    helm repo update >/dev/null 2>&1
    log_success "Helm repos updated"

    # Check if values file exists
    if [ -f "$HELM_VALUES_FILE" ]; then
        log_success "Helm values file found: $HELM_VALUES_FILE"
    else
        log_warn "Helm values file not found: $HELM_VALUES_FILE"
        log_info "Will use default values (not recommended for production)"
    fi

    log_success "All prerequisites satisfied"
}

#═══════════════════════════════════════════════════════════════════
# OIDC PROVIDER SETUP
#═══════════════════════════════════════════════════════════════════

setup_oidc_provider() {
    log_section "STEP 2: SETTING UP OIDC PROVIDER"

    # Get OIDC issuer URL
    log_info "Retrieving cluster OIDC issuer..."
    OIDC_ISSUER=$(aws eks describe-cluster \
        --name "$CLUSTER_NAME" \
        --region "$AWS_REGION" \
        --query "cluster.identity.oidc.issuer" \
        --output text)
    
    if [ -z "$OIDC_ISSUER" ]; then
        error_exit "Failed to retrieve OIDC issuer for cluster $CLUSTER_NAME"
    fi
    
    log_info "OIDC Issuer: $OIDC_ISSUER"
    
    # Extract OIDC ID
    OIDC_ID=$(echo "$OIDC_ISSUER" | sed -e "s/^https:\/\/oidc\.eks\.$AWS_REGION\.amazonaws\.com\/id\///")
    log_info "OIDC ID: $OIDC_ID"

    # Check if OIDC provider already exists
    log_info "Checking if OIDC provider exists..."
    OIDC_PROVIDER_ARN=$(aws iam list-open-id-connect-providers --output json 2>/dev/null | \
        jq -r ".OpenIDConnectProviderList[] | select(.Arn | contains(\"$OIDC_ID\")) | .Arn")

    if [ -n "$OIDC_PROVIDER_ARN" ]; then
        log_success "OIDC provider already exists: $OIDC_PROVIDER_ARN"
    else
        log_info "Creating OIDC provider using eksctl..."
        
        # Use eksctl to create OIDC provider (this is the reliable method)
        if eksctl utils associate-iam-oidc-provider \
            --cluster "$CLUSTER_NAME" \
            --region "$AWS_REGION" \
            --approve; then
            log_success "OIDC provider created successfully"
            
            # Verify it was created
            OIDC_PROVIDER_ARN=$(aws iam list-open-id-connect-providers --output json | \
                jq -r ".OpenIDConnectProviderList[] | select(.Arn | contains(\"$OIDC_ID\")) | .Arn")
            
            if [ -n "$OIDC_PROVIDER_ARN" ]; then
                log_success "OIDC provider ARN: $OIDC_PROVIDER_ARN"
            else
                error_exit "OIDC provider creation failed - provider not found after eksctl command"
            fi
        else
            error_exit "Failed to create OIDC provider using eksctl"
        fi
    fi
}

#═══════════════════════════════════════════════════════════════════
# EBS CSI DRIVER INSTALLATION
#═══════════════════════════════════════════════════════════════════

install_ebs_csi_driver() {
    log_section "STEP 3: INSTALLING EBS CSI DRIVER"

    # Check if addon already exists
    log_info "Checking if EBS CSI Driver addon exists..."
    ADDON_STATUS=$(aws eks describe-addon \
        --cluster-name "$CLUSTER_NAME" \
        --addon-name aws-ebs-csi-driver \
        --region "$AWS_REGION" \
        --query 'addon.status' \
        --output text 2>/dev/null || echo "NOT_FOUND")

    if [ "$ADDON_STATUS" = "ACTIVE" ]; then
        log_success "EBS CSI Driver addon already installed and active"
        return 0
    elif [ "$ADDON_STATUS" = "NOT_FOUND" ]; then
        log_info "EBS CSI Driver addon not found, will install..."
    else
        log_warn "EBS CSI Driver addon exists but status is: $ADDON_STATUS"
        log_info "Will attempt to update/reinstall..."
    fi

    # Create IAM role for EBS CSI Driver using eksctl
    log_info "Creating IAM role for EBS CSI Driver (using eksctl)..."
    
    # eksctl will create:
    # 1. IAM policy (if not exists)
    # 2. IAM role with proper trust relationship
    # 3. Attach policy to role
    # 4. Annotate service account
    
    if eksctl create iamserviceaccount \
        --name ebs-csi-controller-sa \
        --namespace kube-system \
        --cluster "$CLUSTER_NAME" \
        --region "$AWS_REGION" \
        --role-name "AmazonEKS_EBS_CSI_DriverRole_${CLUSTER_NAME}" \
        --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
        --approve \
        --override-existing-serviceaccounts 2>&1 | tee /tmp/eksctl-ebs-csi.log; then
        
        log_success "IAM service account created for EBS CSI Driver"
    else
        # Check if it already exists
        if grep -q "already exists" /tmp/eksctl-ebs-csi.log; then
            log_success "IAM service account already exists"
        else
            log_warn "IAM service account creation had issues, checking if it exists..."
            # Verify service account exists
            if kubectl get sa ebs-csi-controller-sa -n kube-system >/dev/null 2>&1; then
                log_success "Service account verified to exist"
            else
                error_exit "Failed to create IAM service account for EBS CSI Driver"
            fi
        fi
    fi

    # Get the IAM role ARN
    log_info "Retrieving IAM role ARN..."
    IAM_ROLE_ARN=$(kubectl get sa ebs-csi-controller-sa -n kube-system \
        -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}')
    
    if [ -z "$IAM_ROLE_ARN" ]; then
        error_exit "Failed to retrieve IAM role ARN from service account annotation"
    fi
    
    log_success "IAM Role ARN: $IAM_ROLE_ARN"

    # Install EBS CSI Driver addon
    log_info "Installing EBS CSI Driver addon..."
    
    if [ "$ADDON_STATUS" = "NOT_FOUND" ]; then
        # Create new addon
        if aws eks create-addon \
            --cluster-name "$CLUSTER_NAME" \
            --addon-name aws-ebs-csi-driver \
            --service-account-role-arn "$IAM_ROLE_ARN" \
            --region "$AWS_REGION" \
            --resolve-conflicts OVERWRITE; then
            log_success "EBS CSI Driver addon installation initiated"
        else
            error_exit "Failed to create EBS CSI Driver addon"
        fi
    else
        # Update existing addon
        if aws eks update-addon \
            --cluster-name "$CLUSTER_NAME" \
            --addon-name aws-ebs-csi-driver \
            --service-account-role-arn "$IAM_ROLE_ARN" \
            --region "$AWS_REGION" \
            --resolve-conflicts OVERWRITE; then
            log_success "EBS CSI Driver addon update initiated"
        else
            log_warn "Failed to update addon, but it may still work"
        fi
    fi

    # Wait for addon to be active
    log_info "Waiting for EBS CSI Driver addon to become active (this may take 2-3 minutes)..."
    wait_for_condition \
        "[ \"\$(aws eks describe-addon --cluster-name $CLUSTER_NAME --addon-name aws-ebs-csi-driver --region $AWS_REGION --query 'addon.status' --output text 2>/dev/null)\" = 'ACTIVE' ]" \
        "EBS CSI Driver addon to be ACTIVE" \
        300

    # Verify EBS CSI Driver pods are running
    log_info "Verifying EBS CSI Driver pods..."
    wait_for_condition \
        "kubectl get pods -n kube-system -l app=ebs-csi-controller --no-headers 2>/dev/null | grep -q Running" \
        "EBS CSI Controller pods to be Running" \
        180

    # Count running pods
    CSI_CONTROLLER_PODS=$(kubectl get pods -n kube-system -l app=ebs-csi-controller --no-headers 2>/dev/null | grep -c Running || echo 0)
    CSI_NODE_PODS=$(kubectl get pods -n kube-system -l app=ebs-csi-node --no-headers 2>/dev/null | grep -c Running || echo 0)
    
    log_success "EBS CSI Driver pods running:"
    log_info "  Controller pods: $CSI_CONTROLLER_PODS"
    log_info "  Node pods (DaemonSet): $CSI_NODE_PODS"

    # Check for errors in CSI driver logs
    log_info "Checking EBS CSI Driver logs for errors..."
    CSI_POD=$(kubectl get pods -n kube-system -l app=ebs-csi-controller -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -n "$CSI_POD" ]; then
        # Check last 20 lines for critical errors
        if kubectl logs -n kube-system "$CSI_POD" -c ebs-plugin --tail=20 2>/dev/null | grep -i "error\|fatal\|failed" | grep -v "failed to refresh cached credentials" >/dev/null; then
            log_warn "Found errors in CSI driver logs. Showing last 20 lines:"
            kubectl logs -n kube-system "$CSI_POD" -c ebs-plugin --tail=20
            log_warn "Proceeding despite errors - they may be transient"
        else
            log_success "No critical errors in CSI driver logs"
        fi
    fi
}

#═══════════════════════════════════════════════════════════════════
# STORAGE CLASS CREATION
#═══════════════════════════════════════════════════════════════════

create_storage_class() {
    log_section "STEP 4: CREATING STORAGE CLASS"

    # Check if gp3 StorageClass already exists
    if kubectl get storageclass "$STORAGE_CLASS_NAME" >/dev/null 2>&1; then
        log_warn "StorageClass '$STORAGE_CLASS_NAME' already exists"
        
        # Check if it's set as default
        IS_DEFAULT=$(kubectl get storageclass "$STORAGE_CLASS_NAME" -o jsonpath='{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}')
        
        if [ "$IS_DEFAULT" = "true" ]; then
            log_success "StorageClass '$STORAGE_CLASS_NAME' is already the default"
            return 0
        else
            log_info "Setting '$STORAGE_CLASS_NAME' as default StorageClass..."
            kubectl annotate storageclass "$STORAGE_CLASS_NAME" \
                storageclass.kubernetes.io/is-default-class=true \
                --overwrite
            log_success "StorageClass '$STORAGE_CLASS_NAME' set as default"
            return 0
        fi
    fi

    log_info "Creating gp3 StorageClass with encryption..."

    # Create StorageClass manifest
    cat > /tmp/storageclass-gp3.yaml << 'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
  encrypted: "true"
  # gp3 performance parameters
  iops: "3000"        # 3000 IOPS baseline (free)
  throughput: "125"   # 125 MB/s baseline (free)
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete
EOF

    # Apply StorageClass
    if kubectl apply -f /tmp/storageclass-gp3.yaml; then
        log_success "StorageClass 'gp3' created"
    else
        error_exit "Failed to create StorageClass"
    fi

    # Verify it's set as default
    wait_for_condition \
        "kubectl get storageclass gp3 -o jsonpath='{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}' | grep -q true" \
        "StorageClass to be set as default" \
        30

    log_success "StorageClass configuration:"
    kubectl get storageclass "$STORAGE_CLASS_NAME" -o yaml | grep -A 10 "^metadata:\|^parameters:"
}

#═══════════════════════════════════════════════════════════════════
# MONITORING NAMESPACE CREATION
#═══════════════════════════════════════════════════════════════════

create_namespace() {
    log_section "STEP 5: CREATING MONITORING NAMESPACE"

    if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        log_success "Namespace '$NAMESPACE' already exists"
    else
        log_info "Creating namespace '$NAMESPACE'..."
        if kubectl create namespace "$NAMESPACE"; then
            log_success "Namespace '$NAMESPACE' created"
        else
            error_exit "Failed to create namespace"
        fi
    fi

    # Label the namespace
    kubectl label namespace "$NAMESPACE" \
        name=monitoring \
        purpose=observability \
        --overwrite >/dev/null 2>&1
    
    log_success "Namespace labeled"
}

#═══════════════════════════════════════════════════════════════════
# PROMETHEUS STACK DEPLOYMENT
#═══════════════════════════════════════════════════════════════════

deploy_monitoring_stack() {
    log_section "STEP 6: DEPLOYING PROMETHEUS MONITORING STACK"

    # Check if Helm release already exists
    if helm list -n "$NAMESPACE" | grep -q "^$HELM_RELEASE_NAME"; then
        log_warn "Helm release '$HELM_RELEASE_NAME' already exists"
        log_info "Will upgrade existing release..."
        
        # Upgrade existing release
        HELM_COMMAND="upgrade"
        HELM_ARGS="--reuse-values"
    else
        log_info "Installing new Helm release..."
        HELM_COMMAND="install"
        HELM_ARGS=""
    fi

    # Prepare Helm command
    if [ -f "$HELM_VALUES_FILE" ]; then
        log_info "Using custom values file: $HELM_VALUES_FILE"
        HELM_VALUES_ARG="--values $HELM_VALUES_FILE"
    else
        log_warn "No custom values file found, using chart defaults"
        HELM_VALUES_ARG=""
    fi

    # Deploy/Upgrade Helm chart
    log_info "Deploying kube-prometheus-stack..."
    log_info "This will install: Prometheus, Grafana, Alertmanager, kube-state-metrics, node-exporter"
    
    if helm $HELM_COMMAND "$HELM_RELEASE_NAME" "$HELM_CHART" \
        --namespace "$NAMESPACE" \
        $HELM_ARGS \
        $HELM_VALUES_ARG \
        --timeout 10m \
        --wait; then
        log_success "Helm chart deployed successfully"
    else
        error_exit "Helm deployment failed"
    fi

    # Show deployed resources
    log_info "Deployed Helm release info:"
    helm list -n "$NAMESPACE"
}

#═══════════════════════════════════════════════════════════════════
# VALIDATION
#═══════════════════════════════════════════════════════════════════

validate_deployment() {
    log_section "STEP 7: VALIDATING DEPLOYMENT"

    # Wait for all pods to be ready
    log_info "Waiting for all monitoring pods to be ready (this may take 3-5 minutes)..."
    
    # Expected pods:
    # - prometheus-xxx
    # - alertmanager-xxx
    # - grafana-xxx
    # - kube-state-metrics-xxx
    # - node-exporter-xxx (DaemonSet - one per node)
    # - prometheus-operator-xxx

    wait_for_condition \
        "kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | grep -v Running | wc -l | grep -q '^0$'" \
        "All monitoring pods to be Running" \
        600

    # Count pods
    TOTAL_PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers | wc -l)
    RUNNING_PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers | grep Running | wc -l)
    
    log_success "Pod status: $RUNNING_PODS/$TOTAL_PODS Running"

    # Show pod details
    log_info "Monitoring pods:"
    kubectl get pods -n "$NAMESPACE" -o wide

    # Check PVCs are bound
    log_info "Checking PersistentVolumeClaims..."
    PVC_COUNT=$(kubectl get pvc -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l || echo 0)
    
    if [ "$PVC_COUNT" -gt 0 ]; then
        BOUND_PVC=$(kubectl get pvc -n "$NAMESPACE" --no-headers | grep Bound | wc -l)
        log_info "PVC status: $BOUND_PVC/$PVC_COUNT Bound"
        
        if [ "$BOUND_PVC" -ne "$PVC_COUNT" ]; then
            log_warn "Some PVCs are not bound:"
            kubectl get pvc -n "$NAMESPACE"
        else
            log_success "All PVCs are bound"
        fi
    else
        log_info "No PVCs found (persistence may be disabled)"
    fi

    # Check services
    log_info "Checking services..."
    kubectl get svc -n "$NAMESPACE"

    # Verify Prometheus is scraping targets
    log_info "Checking Prometheus targets..."
    PROMETHEUS_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -n "$PROMETHEUS_POD" ]; then
        log_info "Prometheus pod: $PROMETHEUS_POD"
        
        # Port-forward temporarily to check targets
        kubectl port-forward -n "$NAMESPACE" "$PROMETHEUS_POD" 9090:9090 >/dev/null 2>&1 &
        PF_PID=$!
        sleep 3
        
        # Query Prometheus API
        if TARGETS=$(curl -s http://localhost:9090/api/v1/targets 2>/dev/null | jq -r '.data.activeTargets | length' 2>/dev/null); then
            log_success "Prometheus is scraping $TARGETS targets"
        else
            log_warn "Could not verify Prometheus targets (API may not be ready yet)"
        fi
        
        # Kill port-forward
        kill $PF_PID 2>/dev/null || true
    fi

    log_success "Deployment validation complete"
}

#═══════════════════════════════════════════════════════════════════
# POST-DEPLOYMENT INFORMATION
#═══════════════════════════════════════════════════════════════════

show_access_info() {
    log_section "DEPLOYMENT COMPLETE - ACCESS INFORMATION"

    echo ""
    log_info "Your monitoring stack is now deployed and ready!"
    echo ""

    # Prometheus access
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}PROMETHEUS${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "To access Prometheus UI:"
    echo ""
    echo "  # Method 1: Port-forward (from EC2)"
    echo "  kubectl port-forward -n $NAMESPACE svc/monitoring-kube-prometheus-prometheus 9090:9090"
    echo "  # Then open: http://localhost:9090"
    echo ""
    echo "  # Method 2: SSH Tunnel (from your laptop)"
    echo "  ssh -i ~/.ssh/your-key.pem -L 9090:localhost:9090 ubuntu@YOUR_EC2_IP"
    echo "  kubectl port-forward -n $NAMESPACE svc/monitoring-kube-prometheus-prometheus 9090:9090"
    echo "  # Then open: http://localhost:9090 on your laptop"
    echo ""

    # Grafana access
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}GRAFANA${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "To access Grafana UI:"
    echo ""
    echo "  # Port-forward"
    echo "  kubectl port-forward -n $NAMESPACE svc/monitoring-grafana 3000:80"
    echo "  # Then open: http://localhost:3000"
    echo ""
    
    # Get Grafana password
    GRAFANA_PASSWORD=$(kubectl get secret -n "$NAMESPACE" monitoring-grafana -o jsonpath='{.data.admin-password}' 2>/dev/null | base64 -d)
    
    if [ -n "$GRAFANA_PASSWORD" ]; then
        echo "  Login credentials:"
        echo "    Username: admin"
        echo "    Password: $GRAFANA_PASSWORD"
    else
        echo "  Login credentials:"
        echo "    Username: admin"
        echo "    Password: (check your values file or run: kubectl get secret -n $NAMESPACE monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d)"
    fi
    echo ""

    # Alertmanager access
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}ALERTMANAGER${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "To access Alertmanager UI:"
    echo ""
    echo "  kubectl port-forward -n $NAMESPACE svc/monitoring-kube-prometheus-alertmanager 9093:9093"
    echo "  # Then open: http://localhost:9093"
    echo ""

    # Useful commands
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}USEFUL COMMANDS${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  # View all monitoring resources"
    echo "  kubectl get all -n $NAMESPACE"
    echo ""
    echo "  # Check pod logs"
    echo "  kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=prometheus --tail=50"
    echo "  kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=grafana --tail=50"
    echo ""
    echo "  # Restart a component"
    echo "  kubectl rollout restart deployment monitoring-grafana -n $NAMESPACE"
    echo ""
    echo "  # Check Helm release status"
    echo "  helm status $HELM_RELEASE_NAME -n $NAMESPACE"
    echo ""
    echo "  # Upgrade monitoring stack"
    echo "  helm upgrade $HELM_RELEASE_NAME $HELM_CHART -n $NAMESPACE --reuse-values"
    echo ""

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}NEXT STEPS${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  1. Access Grafana and explore pre-configured dashboards"
    echo "  2. Configure custom alert rules (Part 4 - next)"
    echo "  3. Set up Slack integration for alerts"
    echo "  4. Create application-specific dashboards"
    echo "  5. Set up monitoring for your TaskMaster app"
    echo ""
}

#═══════════════════════════════════════════════════════════════════
# ROLLBACK FUNCTION
#═══════════════════════════════════════════════════════════════════

rollback_deployment() {
    log_section "ROLLING BACK DEPLOYMENT"

    log_warn "This will remove the monitoring stack"
    read -p "Are you sure you want to rollback? (yes/NO): " -r
    echo
    if [[ ! $REPLY =~ ^yes$ ]]; then
        log_info "Rollback cancelled"
        exit 0
    fi

    # Uninstall Helm release
    if helm list -n "$NAMESPACE" | grep -q "$HELM_RELEASE_NAME"; then
        log_info "Uninstalling Helm release..."
        helm uninstall "$HELM_RELEASE_NAME" -n "$NAMESPACE"
        log_success "Helm release uninstalled"
    fi

    # Delete namespace
    if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        log_info "Deleting namespace..."
        kubectl delete namespace "$NAMESPACE" --wait=true
        log_success "Namespace deleted"
    fi

    # Delete StorageClass (optional)
    read -p "Delete StorageClass 'gp3'? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl delete storageclass gp3 2>/dev/null || true
        log_success "StorageClass deleted"
    fi

    # Note: We don't delete OIDC provider or EBS CSI driver as they may be used by other apps

    log_success "Rollback complete"
}

#═══════════════════════════════════════════════════════════════════
# MAIN EXECUTION
#═══════════════════════════════════════════════════════════════════

main() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                                   ║${NC}"
    echo -e "${CYAN}║         MONITORING STACK DEPLOYMENT AUTOMATION                   ║${NC}"
    echo -e "${CYAN}║         Prometheus + Grafana + Alertmanager                       ║${NC}"
    echo -e "${CYAN}║                                                                   ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Parse arguments
    if [ "$1" = "rollback" ]; then
        rollback_deployment
        exit 0
    fi

    # Show configuration
    log_info "Deployment Configuration:"
    log_info "  Cluster: $CLUSTER_NAME"
    log_info "  Region: $AWS_REGION"
    log_info "  Namespace: $NAMESPACE"
    log_info "  Helm Chart: $HELM_CHART"
    log_info "  Release Name: $HELM_RELEASE_NAME"
    echo ""

    # Confirm deployment
    read -p "Proceed with deployment? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log_info "Deployment cancelled"
        exit 0
    fi

    # Execute deployment steps
    START_TIME=$(date +%s)

    check_prerequisites
    setup_oidc_provider
    install_ebs_csi_driver
    create_storage_class
    create_namespace
    deploy_monitoring_stack
    validate_deployment
    show_access_info

    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    MINUTES=$((DURATION / 60))
    SECONDS=$((DURATION % 60))

    echo ""
    log_success "═══════════════════════════════════════════════════════════════════"
    log_success "DEPLOYMENT COMPLETED SUCCESSFULLY in ${MINUTES}m ${SECONDS}s"
    log_success "═══════════════════════════════════════════════════════════════════"
    echo ""
}

# Run main function
main "$@"
