# 🚀 DevOps Portfolio: End-to-End 3-Tier Web Application with CI/CD

[![AWS](https://img.shields.io/badge/AWS-Free%20Tier-orange)](https://aws.amazon.com/free/)
[![Terraform](https://img.shields.io/badge/Terraform-v1.9+-purple)](https://www.terraform.io/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.30+-blue)](https://kubernetes.io/)
[![Docker](https://img.shields.io/badge/Docker-20.10+-blue)](https://www.docker.com/)

## 📋 Project Overview

A production-grade, fully automated 3-tier web application deployed on AWS using Infrastructure as Code (Terraform), containerized with Docker, orchestrated with Kubernetes, and continuously deployed via GitHub Actions.

**Portfolio Goal:** Demonstrate end-to-end DevOps capabilities from infrastructure provisioning to application deployment, monitoring, and cost optimization.

## 🏗️ Architecture
```
┌─────────────────────────────────────────────────────────┐
│ AWS Cloud (Free Tier)                                   │
│ ┌───────────────────────────────────────────────────┐   │
│ │ VPC (10.0.0.0/16)                                 │   │
│ │ ┌─────────────┐ ┌─────────────┐ ┌──────────┐      │   │
│ │ │ Public      │ │ Private     │ │ Private  │      │   │
│ │ │ Subnet      │ │ Subnet      │ │ Subnet   │      │   │
│ │ │             │ │             │ │          │      │   │
│ │ │ [ALB]       │ │ [K8s Nodes] │ │ [DB]     │      │   │
│ │ │ [NAT GW]    │ │ [App Pods]  │ │ [Data]   │      │   │
│ │ └─────────────┘ └─────────────┘ └──────────┘      │   │
│ └───────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

**Tech Stack:**
- **Cloud:** AWS (m7i-flex.large, t3.micro)
- **IaC:** Terraform with modular design
- **Orchestration:** Self-managed Kubernetes (kubeadm)
- **CI/CD:** GitHub Actions
- **Monitoring:** Prometheus + Grafana + ELK Stack
- **Application:** React + Node.js/Python + MongoDB/PostgreSQL

## 💰 Cost Breakdown
```
| Component        | Instance Type  | Monthly Cost | Status              |
|------------------|----------------|--------------|---------------------|
| K8s Master       | m7i-flex.large | $0 (credits) | ✅ Free Tier        |
| K8s Workers (2x) | m7i-flex.large | $0 (credits) | ✅ Free Tier        |
| Bastion Host     | t3.micro       | $0 (credits) | ✅ Free Tier        |
| Monitoring       | t3.small       | $0 (credits) | ✅ Free Tier        |
| **Total**        |                | **~$0**      | **6-month credits** |
```


## 📁 Repository Structure
```
devops-portfolio-3tier-app/
├── terraform/ # Infrastructure as Code
│ ├── modules/ # Reusable Terraform modules
│ │ ├── vpc/ # Network infrastructure
│ │ ├── security/ # Security groups, IAM roles
│ │ ├── compute/ # EC2 instances
│ │ └── kubernetes/ # K8s cluster resources
│ └── environments/ # Environment-specific configs
│ ├── dev/
│ ├── staging/
│ └── prod/
├── kubernetes/ # Kubernetes manifests
│ ├── manifests/
│ │ ├── frontend/
│ │ ├── backend/
│ │ └── database/
│ └── helm-charts/
├── application/ # Application code
│ ├── frontend/ # React app
│ ├── backend/ # Node.js/Python API
│ └── database/ # DB schemas, migrations
├── ansible/ # Configuration management
│ ├── playbooks/
│ ├── roles/
│ └── inventory/
├── ci-cd/ # CI/CD pipeline configs
│ ├── github-actions/
│ └── jenkins/
├── monitoring/ # Monitoring configs
│ ├── prometheus/
│ ├── grafana/
│ └── elk/
├── scripts/ # Automation scripts
│ ├── startup/ # Start infrastructure
│ ├── shutdown/ # Stop infrastructure (cost-saving)
│ └── backup/ # Backup scripts
└── docs/ # Documentation
├── architecture/
└── runbooks/
```

## 🚦 Quick Start

### Prerequisites
- AWS Account (created after July 15, 2025 for free tier credits)
- Local tools: AWS CLI, Docker, kubectl, Terraform, Ansible, Minikube

### Local Development
Clone repository
```
git clone https://github.com/YOUR_USERNAME/devops-portfolio-3tier-app.git
cd devops-portfolio-3tier-app
```

Test application locally with Docker Compose
```
cd application
docker-compose up
```

Test Kubernetes manifests on Minikube
```
minikube start
kubectl apply -f kubernetes/manifests/
```

### AWS Deployment
Initialize Terraform
```
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

Deploy application to Kubernetes
```
cd ../../../kubernetes/manifests
kubectl apply -f .
```

## 🛑 Cost-Saving: Shutdown When Not in Use

Stop all AWS resources (saves credits!)
```
./scripts/shutdown/stop-all-resources.sh
```

Start resources when needed
```
./scripts/startup/start-all-resources.sh
```

## 📊 Key Features

- ✅ **Infrastructure as Code**: 100% Terraform-managed infrastructure
- ✅ **Self-Managed Kubernetes**: Production-grade cluster with kubeadm
- ✅ **CI/CD Pipeline**: Automated build, test, and deployment
- ✅ **Monitoring Stack**: Prometheus + Grafana + ELK
- ✅ **Security Best Practices**: IAM roles, Security Groups, Secrets Management
- ✅ **Cost-Optimized**: Free tier maximization, auto-shutdown scripts
- ✅ **High Availability**: Multi-AZ deployment, auto-healing
- ✅ **Documentation**: Comprehensive runbooks and architecture diagrams

## 🎓 Learning Outcomes

This project demonstrates:
- AWS infrastructure provisioning and management
- Kubernetes cluster administration (bootstrapping, networking, storage)
- Container orchestration and microservices deployment
- CI/CD pipeline design and implementation
- Infrastructure monitoring and observability
- Cloud cost optimization strategies
- Security hardening and compliance

## 📝 Blog Posts & Documentation

- [Architecture Deep Dive](docs/architecture/README.md)
- [Cost Optimization Strategies](docs/runbooks/cost-optimization.md)
- [Kubernetes Troubleshooting Guide](docs/runbooks/k8s-troubleshooting.md)
- [CI/CD Pipeline Explained](docs/runbooks/cicd-pipeline.md)

## 🤝 Contributing

This is a portfolio project, but feedback and suggestions are welcome! Open an issue or submit a PR.

## 📧 Contact

**Sarthak Vaish**  
DevOps Engineer | Transitioning from Operations Support  
📧sarthakvaish31@gmail.com  
🔗 [LinkedIn](https://linkedin.com/in/sarthakvaish007)  
🐙 [GitHub](https://github.comsarthak9876)

## 📜 License

MIT License - feel free to use this as inspiration for your own portfolio!

---

**Status:** 🚧 Work in Progress | Current Phase: Infrastructure Foundation

## 🚀 Quick Start - New Workstation Setup

Setting up the project on a new machine? Run the automated bootstrap:

```bash
# Clone repository
git clone https://github.com/YOUR_USERNAME/devops-portfolio-3tier-app.git
cd devops-portfolio-3tier-app

# Run bootstrap (installs Docker, kubectl, Helm, Terraform, AWS CLI, Node.js, etc.)
./scripts/bootstrap/setup-workstation.sh

# Log out and log back in (required for Docker permissions)
exit

# Verify installation
./scripts/bootstrap/check-prerequisites.sh

# Configure AWS
aws configure

# Validate AWS setup
./scripts/bootstrap/validate-aws-setup.sh
See Bootstrap Guide for detailed instructions.
