#!/bin/bash
# LoadBalancer Diagnostic Script
# Comprehensive check of AWS LoadBalancer, EKS services, and pods

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="taskmaster-dev"

echo -e "${BLUE}🔍 LoadBalancer & Service Diagnostic${NC}"
echo "======================================"
echo ""

# 1. Check AWS LoadBalancer Controller
echo -e "${YELLOW}1. Checking AWS LoadBalancer Controller...${NC}"
LB_CONTROLLER=$(kubectl get deployment -n kube-system | grep aws-load-balancer-controller || echo "Not found")
if [[ $LB_CONTROLLER == *"Not found"* ]]; then
    echo -e "${RED}❌ AWS LoadBalancer Controller not found in kube-system${NC}"
    echo "   This is required for LoadBalancer services to work"
else
    echo -e "${GREEN}✅ AWS LoadBalancer Controller found${NC}"
fi
echo ""

# 2. Check all services
echo -e "${YELLOW}2. Checking Kubernetes Services...${NC}"
kubectl get svc -n $NAMESPACE
echo ""

# 3. Check frontend LoadBalancer specifically
echo -e "${YELLOW}3. Checking Frontend LoadBalancer Details...${NC}"
LB_SVC=$(kubectl get svc frontend-loadbalancer -n $NAMESPACE 2>/dev/null || echo "Not found")
if [[ $LB_SVC == *"Not found"* ]]; then
    echo -e "${RED}❌ Frontend LoadBalancer service not found${NC}"
    echo "   The service hasn't been created yet"
else
    echo -e "${GREEN}✅ Frontend LoadBalancer service exists${NC}"

    # Check LoadBalancer status
    LB_STATUS=$(kubectl get svc frontend-loadbalancer -n $NAMESPACE -o jsonpath='{.status.loadBalancer}' 2>/dev/null || echo "{}")
    if [[ $LB_STATUS == "{}" ]] || [[ $LB_STATUS == "" ]]; then
        echo -e "${RED}❌ LoadBalancer has no external IP/hostname${NC}"
        echo "   AWS NLB hasn't been provisioned yet (takes 2-3 minutes)"
    else
        LB_HOSTNAME=$(kubectl get svc frontend-loadbalancer -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        LB_IP=$(kubectl get svc frontend-loadbalancer -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

        if [[ -n "$LB_HOSTNAME" ]]; then
            echo -e "${GREEN}✅ LoadBalancer hostname: ${LB_HOSTNAME}${NC}"
            echo "   🌐 Try accessing: http://${LB_HOSTNAME}"
        elif [[ -n "$LB_IP" ]]; then
            echo -e "${GREEN}✅ LoadBalancer IP: ${LB_IP}${NC}"
            echo "   🌐 Try accessing: http://${LB_IP}"
        else
            echo -e "${RED}❌ LoadBalancer exists but no hostname/IP assigned${NC}"
        fi
    fi
fi
echo ""

# 4. Check all pods
echo -e "${YELLOW}4. Checking Pod Status...${NC}"
kubectl get pods -n $NAMESPACE
echo ""

# 5. Check frontend pod details
echo -e "${YELLOW}5. Checking Frontend Pod Details...${NC}"
FRONTEND_PODS=$(kubectl get pods -n $NAMESPACE -l app=frontend -o name 2>/dev/null | wc -l)
if [[ $FRONTEND_PODS -eq 0 ]]; then
    echo -e "${RED}❌ No frontend pods found${NC}"
else
    echo -e "${GREEN}✅ $FRONTEND_PODS frontend pod(s) found${NC}"

    # Check if pods are ready
    READY_PODS=$(kubectl get pods -n $NAMESPACE -l app=frontend -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' | grep -o "True" | wc -l)
    if [[ $READY_PODS -eq 0 ]]; then
        echo -e "${RED}❌ No frontend pods are ready${NC}"
        echo "   Check pod logs:"
        echo "   kubectl logs -n $NAMESPACE -l app=frontend --tail=50"
    else
        echo -e "${GREEN}✅ $READY_PODS frontend pod(s) are ready${NC}"
    fi
fi
echo ""

# 6. Check backend connectivity
echo -e "${YELLOW}6. Checking Backend Service...${NC}"
BACKEND_SVC=$(kubectl get svc backend-service -n $NAMESPACE 2>/dev/null || echo "Not found")
if [[ $BACKEND_SVC == *"Not found"* ]]; then
    echo -e "${RED}❌ Backend service not found${NC}"
else
    echo -e "${GREEN}✅ Backend service exists${NC}"

    # Test backend connectivity from a pod
    BACKEND_PODS=$(kubectl get pods -n $NAMESPACE -l app=backend -o name 2>/dev/null | wc -l)
    if [[ $BACKEND_PODS -gt 0 ]]; then
        echo -e "${YELLOW}Testing backend health check...${NC}"
        BACKEND_POD=$(kubectl get pods -n $NAMESPACE -l app=backend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        if [[ -n "$BACKEND_POD" ]]; then
            HEALTH_CHECK=$(kubectl exec $BACKEND_POD -n $NAMESPACE -- curl -s http://localhost:5000/health 2>/dev/null || echo "Failed")
            if [[ $HEALTH_CHECK == *"Failed"* ]]; then
                echo -e "${RED}❌ Backend health check failed${NC}"
                echo "   Backend pod may not be responding on port 5000"
            else
                echo -e "${GREEN}✅ Backend health check passed${NC}"
            fi
        fi
    fi
fi
echo ""

# 7. Check MongoDB
echo -e "${YELLOW}7. Checking MongoDB Service...${NC}"
MONGO_SVC=$(kubectl get svc mongodb-service -n $NAMESPACE 2>/dev/null || echo "Not found")
if [[ $MONGO_SVC == *"Not found"* ]]; then
    echo -e "${RED}❌ MongoDB service not found${NC}"
else
    echo -e "${GREEN}✅ MongoDB service exists${NC}"

    MONGO_PODS=$(kubectl get pods -n $NAMESPACE -l app=mongodb -o name 2>/dev/null | wc -l)
    if [[ $MONGO_PODS -gt 0 ]]; then
        MONGO_POD=$(kubectl get pods -n $NAMESPACE -l app=mongodb -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        MONGO_TEST=$(kubectl exec $MONGO_POD -n $NAMESPACE -- mongo --eval "db.stats()" --quiet 2>/dev/null | grep -q "ok" && echo "OK" || echo "Failed")
        if [[ $MONGO_TEST == "OK" ]]; then
            echo -e "${GREEN}✅ MongoDB is accessible${NC}"
        else
            echo -e "${RED}❌ MongoDB connection failed${NC}"
        fi
    fi
fi
echo ""

# 8. Summary and recommendations
echo -e "${BLUE}📋 SUMMARY & RECOMMENDATIONS${NC}"
echo "=============================="

# Check if LoadBalancer is ready
LB_READY=false
if kubectl get svc frontend-loadbalancer -n $NAMESPACE &>/dev/null; then
    LB_HOSTNAME=$(kubectl get svc frontend-loadbalancer -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    LB_IP=$(kubectl get svc frontend-loadbalancer -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [[ -n "$LB_HOSTNAME" ]] || [[ -n "$LB_IP" ]]; then
        LB_READY=true
    fi
fi

if [[ "$LB_READY" == "true" ]]; then
    if [[ -n "$LB_HOSTNAME" ]]; then
        echo -e "${GREEN}✅ LoadBalancer is ready: http://${LB_HOSTNAME}${NC}"
    else
        echo -e "${GREEN}✅ LoadBalancer is ready: http://${LB_IP}${NC}"
    fi
    echo "   If you still can't access it:"
    echo "   - Check AWS Security Groups for ports 80/443"
    echo "   - Verify your internet connection"
    echo "   - Try a different browser or incognito mode"
else
    echo -e "${RED}❌ LoadBalancer is not ready yet${NC}"
    echo "   Wait 2-3 minutes for AWS to provision the NLB"
    echo "   Run this script again to check progress"
fi

# Check if all components are ready
ALL_READY=true

# Check pods
TOTAL_PODS=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | wc -l)
READY_PODS=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | grep -c "Running")
if [[ $READY_PODS -lt $TOTAL_PODS ]]; then
    ALL_READY=false
    echo -e "${RED}❌ Not all pods are running${NC}"
fi

# Check services
SERVICES=("frontend-loadbalancer" "backend-service" "mongodb-service")
for svc in "${SERVICES[@]}"; do
    if ! kubectl get svc $svc -n $NAMESPACE &>/dev/null; then
        ALL_READY=false
        echo -e "${RED}❌ Service $svc is missing${NC}"
    fi
done

if [[ "$ALL_READY" == "true" ]] && [[ "$LB_READY" == "true" ]]; then
    echo -e "${GREEN}✅ All components appear to be ready!${NC}"
else
    echo -e "${YELLOW}⚠️  Some components are not ready yet${NC}"
    echo "   - Check pod logs: kubectl logs -n $NAMESPACE -l app=frontend"
    echo "   - Check AWS console for LoadBalancer status"
fi
