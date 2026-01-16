#!/bin/bash


echo "1. Installing Kubectl"

curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

echo "2. Checking kubelet version"
kubectl version --client

echo "3. Setting AWS_REGION and CLUSTER_NAME variable"

AWS_REGION="us-east-1"
CLUSTER_NAME=$(terraform output -raw eks_cluster_name)

echo "4. Updating kubeconfig"
aws eks update-kubeconfig \
  --name "$CLUSTER_NAME" \
  --region "$AWS_REGION"


echo "5. Test connectivity"
kubectl get nodes
kubectl get ns

echo "6. Pushing Frontend and Backend Script to AWS ECR"
aws ecr create-repository --repository-name taskmaster-frontend --region "$AWS_REGION"
aws ecr create-repository --repository-name taskmaster-backend  --region "$AWS_REGION"

echo "7. Setting ENV value of ACCOUNT_ID,FRONTEND_REPO,BACKEND_REPO"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

FRONTEND_REPO="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/taskmaster-frontend"
BACKEND_REPO="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/taskmaster-backend"

echo "8. Check AWS ECR Docker login"
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"


echo "9. Build and push images of existing app to ECR"
# Frontend
docker build -t taskmaster-frontend:latest ./application/frontend
docker tag taskmaster-frontend:latest "$FRONTEND_REPO:latest"
docker push "$FRONTEND_REPO:latest"

# Backend
docker build -t taskmaster-backend:latest ./application/backend
docker tag taskmaster-backend:latest "$BACKEND_REPO:latest"
docker push "$BACKEND_REPO:latest"


