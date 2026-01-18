# Bootstrap Guide - Setting Up a New Workstation

## Overview

This guide explains how to set up a new workstation (EC2, laptop, etc.) with all dependencies required for the TaskMaster DevOps Portfolio project.

## Quick Start

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/devops-portfolio-3tier-app.git
cd devops-portfolio-3tier-app

# Run bootstrap script
./scripts/bootstrap/setup-workstation.sh

# Log out and log back in (for Docker group permissions)
exit
# (reconnect)

# Validate setup
./scripts/bootstrap/check-prerequisites.sh

# Configure AWS
aws configure
# Enter: Access Key ID, Secret Access Key, Region (us-east-1), Output (json)

# Validate AWS setup
./scripts/bootstrap/validate-aws-setup.sh
What Gets Installed
Core Tools
Tool	Version	Purpose
Docker	Latest	Container runtime
Docker Compose	2.24.5	Multi-container orchestration
AWS CLI	v2	AWS service interaction
kubectl	1.30.0	Kubernetes cluster management
Helm	3.14.0	Kubernetes package manager
Terraform	1.7.0	Infrastructure as Code
Node.js	20.x	Frontend development & build
npm	Latest	Node package manager
Optional Tools (Productivity)
Tool	Purpose
k9s	Interactive Kubernetes UI
kubectx/kubens	Context/namespace switcher
stern	Multi-pod log tailing
yq	YAML processor
System Packages
curl, wget, git, jq, unzip, tar

build-essential (gcc, make)

Python 3 + pip

tree, htop, net-tools

Supported Operating Systems
✅ Fully Supported:

Ubuntu 22.04 LTS

Ubuntu 24.04 LTS

Amazon Linux 2023

⚠️ Partial Support:

Debian 11/12 (should work, not extensively tested)

RHEL 8/9, CentOS 8/9 (package names may differ)

❌ Not Supported:

macOS (requires different installation methods)

Windows (use WSL2 with Ubuntu)

Manual Installation (If Script Fails)
Docker
bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Amazon Linux
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user
AWS CLI
bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
kubectl
bash
curl -LO "https://dl.k8s.io/release/v1.30.0/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
Helm
bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
Terraform
bash
wget https://releases.hashicorp.com/terraform/1.7.0/terraform_1.7.0_linux_amd64.zip
unzip terraform_1.7.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
Node.js (via NVM)
bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc
nvm install 20
nvm use 20
Post-Installation
1. Verify Installation
bash
./scripts/bootstrap/check-prerequisites.sh
Expected output: ALL CHECKS PASSED!

2. Configure AWS
bash
aws configure
Enter:

AWS Access Key ID: Your IAM user access key

AWS Secret Access Key: Your IAM user secret

Default region: us-east-1

Default output format: json

3. Validate AWS Setup
bash
./scripts/bootstrap/validate-aws-setup.sh
Should show:

✅ AWS CLI installed

✅ Credentials valid

✅ Permissions checked

4. Generate SSH Key (if needed)
bash
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
cat ~/.ssh/id_rsa.pub
# Add to GitHub: https://github.com/settings/keys
5. Test Docker (without sudo)
bash
docker ps
docker run hello-world
If you get permission errors:

bash
sudo usermod -aG docker $USER
# Log out and log back in
Troubleshooting
Docker Permission Denied
Problem: permission denied while trying to connect to the Docker daemon socket

Solution:

bash
sudo usermod -aG docker $USER
# Log out and log back in (required!)
AWS CLI Not Found
Problem: aws: command not found

Solution:

bash
# Check installation
which aws
# If not in PATH, add to ~/.bashrc:
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
kubectl Connection Refused
Problem: The connection to the server localhost:8080 was refused

Solution:

bash
# Configure kubectl for EKS
aws eks update-kubeconfig --region us-east-1 --name taskmaster-dev-cluster

# Verify
kubectl get nodes
Helm Command Not Found
Problem: helm: command not found

Solution:

bash
# Reinstall Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify
helm version
Log Files
Bootstrap script logs everything to:

text
logs/bootstrap-YYYYMMDD-HHMMSS.log
Check this file for detailed error messages if installation fails.

Security Considerations
AWS Credentials
Never commit AWS credentials to Git!

The bootstrap script configures credentials in ~/.aws/credentials, which is:

✅ NOT tracked by Git (.gitignore includes .aws/)

✅ Only readable by your user (chmod 600)

✅ Separate from application code

SSH Keys
Private keys should remain private!

✅ ~/.ssh/id_rsa: Private key (never share)

✅ ~/.ssh/id_rsa.pub: Public key (safe to share, add to GitHub)

Docker Group
Adding user to docker group grants root-equivalent access. This is necessary for development but understand the security implications.

In production:

Use rootless Docker mode

Use Kubernetes RBAC for access control

Limit docker group membership

Next Steps
After bootstrap is complete:

Deploy Infrastructure:

bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
Build Application Images:

bash
cd ~/devops-portfolio-3tier-app
./scripts/build-images.sh  # (to be created)
Deploy to Kubernetes:

bash
kubectl apply -f kubernetes/manifests/
Install Monitoring:

bash
./scripts/deploy-monitoring.sh  # (Phase 4)
Interview Talking Points
Question: "How do you onboard new team members to your project?"

Answer:
"I created an automated bootstrap script that installs all dependencies (Docker, kubectl, Helm, Terraform, AWS CLI, Node.js) on a fresh workstation. The script:

Detects the operating system (Ubuntu, Amazon Linux, etc.)

Installs tools in the correct versions we're using

Configures shell completions for kubectl and Helm

Logs everything for troubleshooting

Verifies all installations work before proceeding

This means a new engineer can clone the repo, run one script, and be ready to deploy within 15 minutes. No more 'works on my machine' issues—everyone has identical tooling."

Question: "What if the script fails?"

Answer:
"The script is designed with robust error handling:

set -euo pipefail: Exits immediately on any error

All output logged to timestamped log files

Each installation function returns success/failure

Verification step at the end checks all tools are working

Comprehensive troubleshooting guide in docs/

If a step fails, the log file shows exactly what went wrong, and the docs explain manual installation steps as a fallback."

Maintenance
Updating Tool Versions
Edit scripts/bootstrap/setup-workstation.sh version constants:

bash
readonly KUBECTL_VERSION="1.30.0"  # Update here
readonly HELM_VERSION="3.14.0"     # Update here
readonly TERRAFORM_VERSION="1.7.0"  # Update here
Testing Bootstrap Script
Before committing changes, test on a fresh EC2 instance:

bash
# Launch Ubuntu 22.04 EC2
# SSH in
git clone <your-repo>
cd devops-portfolio-3tier-app
./scripts/bootstrap/setup-workstation.sh

# Verify
./scripts/bootstrap/check-prerequisites.sh
Resources
Docker Installation Docs

AWS CLI v2 Installation

kubectl Installation

Helm Installation

Terraform Installation
