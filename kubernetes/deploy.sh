# ═══════════════════════════════════════════════════════
# TaskMaster Kubernetes Deployment Script
# Deploys all manifests to EKS cluster
# ═══════════════════════════════════════════════════════

set -e

#Set color
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color


echo "════════════════════════════════════════════════════════"
echo "TaskMaster Kubernetes Deployment"
echo "════════════════════════════════════════════════════════"
echo ""

#Check kubectl connectivity
echo -e "${YELLOW}1. Checking kubectl connectivity...${NC}"
if ! kubectl cluster-info &> /dev/null; then
  echo -e "${RED}❌ Cannot conenct to kubernetes cluster${NC}"
  echo "RUN: aws eks update-kubeconfig --name taskmaster-dev-eks  --region us-east-1"
  exit 1
fi

echo -e "${GREEN}✅ Connected to cluster${NC}"
echo ""

# Apply Manifests in order
echo -e "${YELLOW}2. Creating namespace ${NC}"
kubectl apply -f manifests/00-namespace.yml
echo ""

echo -e "${YELLOW}3. Setting Namespace Context...${NC}"
kubectl config set-context --current --namespace=taskmaster-dev
echo ""

echo -e "${YELLOW}4. Creating configmap...${NC}"
kubectl apply -f manifests/01-configmap.yml
echo ""

echo -e "${YELLOW}5. Creating Secrets...${NC}"
envsubst < manifests/02-secrets.yml | kubectl apply -f -
echo ""

echo -e "${YELLOW}6. Deploying MongoDB...${NC}"
kubectl apply -f manifests/03-mongodb-deployment.yml
echo "Waiting for MongoDB to be ready..."
kubectl wait --for=condition=ready pod -l app=mongodb --timeout=120s
echo -e "${GREEN}✅ MongoDB Reay.${NC}"
echo ""

echo -e "${YELLOW}7. Deploying backend...${NC}"
envsubst < manifests/04-backend-deployment.yml | kubectl apply -f -
echo -e  "Waiting for Backend dpeloyment...${NC}"
kubectl wait --for=condition=ready pod -l app=backend --timeout=120s
echo -e "${GREEN}✅  Bacend Ready${NC}"
echo ""

echo -e "${YELLOW}8. Deploying frontend...${NC}"
envsubst < manifests/05-frontend-deployment.yml | kubectl apply -f -
echo -e "Waiting for Frontend dpeloyment...${NC}"
kubectl wait --for=condition=ready pod -l app=frontend --timeout=120s
echo -e "${GREEN}✅ Frontend Ready${NC}"
echo ""

# Get LoadBalancer URL
echo -e "${YELLOW}9. Getting LoadBalancer URL...${NC}"
echo "Waiting for LoadBalancer to provision this takes 2-3 minutes..."
kubectl wait --for=jsonpath='{.status.loadBalancer.ingress}' service/frontend-loadbalancer --timeout=300s

LB_URL=$(kubectl get svc frontend-loadbalancer -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
if [-z "$LB_URL"]; then
  LB_URL=$(kubectl get svc frontend-loadbalancer -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo -e "${GREEN}✅ DEPLOYMENT COMPLETE${NC}"
echo "════════════════════════════════════════════════════════"
echo ""
echo "📊 Deployment Status:"
kubectl get pods,svc
echo ""
echo "🌐 Access URLs:"
echo "   Frontend: http://${LB_URL}"
echo "   Backend \(internal\): backend-service.taskmaster-dev.svc.cluster.local:5000"
echo ""
echo "📝 Useful Commands:"
echo "   kubectl get pods                    # View pods"
echo "   kubectl logs -f <pod-name>         # View logs"
echo "   kubectl describe pod <pod-name>    # Debug pod"
echo "   kubectl exec -it <pod-name> -- bash  # Shell into pod"
echo ""
