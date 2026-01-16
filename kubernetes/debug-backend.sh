#!/bin/bash
# ═══════════════════════════════════════════════════════
# Backend MongoDB Connection Debugging
# ═══════════════════════════════════════════════════════

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="taskmaster-dev"

echo "════════════════════════════════════════════════════════"
echo "Backend MongoDB Connection Debugging"
echo "════════════════════════════════════════════════════════"
echo ""

# Get backend pods
BACKEND_PODS=($(kubectl get pod -n $NAMESPACE -l app=backend -o jsonpath='{.items[*].metadata.name}'))

if [ ${#BACKEND_PODS[@]} -eq 0 ]; then
    echo -e "${RED}❌ No backend pods found${NC}"
    exit 1
fi

BACKEND_POD=${BACKEND_PODS[0]}
echo "Using backend pod: $BACKEND_POD"
echo ""

# TEST 1: Check Pod Status
echo -e "${YELLOW}TEST 1: Backend Pod Status${NC}"
kubectl get pod $BACKEND_POD -n $NAMESPACE
echo ""

# TEST 2: Check Container Restarts
echo -e "${YELLOW}TEST 2: Container Restart Count${NC}"
RESTARTS=$(kubectl get pod $BACKEND_POD -n $NAMESPACE -o jsonpath='{.status.containerStatuses[0].restartCount}')
echo "Restarts: $RESTARTS"
if [ "$RESTARTS" -gt 0 ]; then
    echo -e "${RED}⚠️  Pod has restarted $RESTARTS times (indicates crashes)${NC}"
fi
echo ""

# TEST 3: Check Environment Variables
echo -e "${YELLOW}TEST 3: Backend Environment Variables${NC}"
echo "All MongoDB-related env vars:"
kubectl exec $BACKEND_POD -n $NAMESPACE -- env | grep -i mongo | sort || echo -e "${RED}No MONGO env vars found!${NC}"
echo ""

echo "All environment variables (for debugging):"
kubectl exec $BACKEND_POD -n $NAMESPACE -- env | sort
echo ""

# TEST 4: Check Backend Logs
echo -e "${YELLOW}TEST 4: Backend Logs (last 50 lines)${NC}"
kubectl logs $BACKEND_POD -n $NAMESPACE --tail=50
echo ""

echo -e "${YELLOW}Searching for error patterns...${NC}"
if kubectl logs $BACKEND_POD -n $NAMESPACE --tail=100 | grep -iq "mongoservererror\|authentication failed"; then
    echo -e "${RED}❌ MongoDB authentication error found:${NC}"
    kubectl logs $BACKEND_POD -n $NAMESPACE --tail=100 | grep -i "mongoservererror\|authentication"
elif kubectl logs $BACKEND_POD -n $NAMESPACE --tail=100 | grep -iq "econnrefused"; then
    echo -e "${RED}❌ MongoDB connection refused:${NC}"
    kubectl logs $BACKEND_POD -n $NAMESPACE --tail=100 | grep -i "econnrefused"
elif kubectl logs $BACKEND_POD -n $NAMESPACE --tail=100 | grep -iq "etimedout"; then
    echo -e "${RED}❌ MongoDB connection timeout:${NC}"
    kubectl logs $BACKEND_POD -n $NAMESPACE --tail=100 | grep -i "etimedout"
elif kubectl logs $BACKEND_POD -n $NAMESPACE --tail=100 | grep -iq "mongo.*connected\|connected to.*mongo\|database connected"; then
    echo -e "${GREEN}✅ MongoDB connection successful${NC}"
else
    echo -e "${YELLOW}⚠️  No clear MongoDB connection status in logs${NC}"
fi
echo ""

# TEST 5: Test Network Connectivity to MongoDB
echo -e "${YELLOW}TEST 5: Network Connectivity to MongoDB${NC}"
echo "Testing if backend can reach MongoDB service..."

# Try netcat
if kubectl exec $BACKEND_POD -n $NAMESPACE -- which nc &>/dev/null; then
    if kubectl exec $BACKEND_POD -n $NAMESPACE -- nc -zv mongodb-service 27017 2>&1 | grep -q succeeded; then
        echo -e "${GREEN}✅ Backend can reach MongoDB on port 27017${NC}"
    else
        echo -e "${RED}❌ Backend cannot reach MongoDB${NC}"
    fi
else
    # Try wget
    if kubectl exec $BACKEND_POD -n $NAMESPACE -- timeout 3 wget -q -O- mongodb-service:27017 &>/dev/null; then
        echo -e "${GREEN}✅ Backend can reach MongoDB${NC}"
    else
        echo -e "${RED}❌ Backend cannot reach MongoDB${NC}"
    fi
fi
echo ""

# TEST 6: DNS Resolution
echo -e "${YELLOW}TEST 6: DNS Resolution${NC}"
echo "Checking if backend can resolve mongodb-service..."
kubectl exec $BACKEND_POD -n $NAMESPACE -- nslookup mongodb-service 2>&1 || kubectl exec $BACKEND_POD -n $NAMESPACE -- getent hosts mongodb-service
echo ""

# TEST 7: Check MongoDB Service Endpoints
echo -e "${YELLOW}TEST 7: MongoDB Service Endpoints${NC}"
kubectl get endpoints mongodb-service -n $NAMESPACE
ENDPOINT_COUNT=$(kubectl get endpoints mongodb-service -n $NAMESPACE -o jsonpath='{.subsets[*].addresses[*].ip}' | wc -w)
if [ "$ENDPOINT_COUNT" -eq 0 ]; then
    echo -e "${RED}❌ MongoDB service has NO endpoints (no pods selected)${NC}"
else
    echo -e "${GREEN}✅ MongoDB service has $ENDPOINT_COUNT endpoint(s)${NC}"
fi
echo ""

# TEST 8: Test Backend Health Endpoint
echo -e "${YELLOW}TEST 8: Backend Health Endpoint${NC}"
echo "Testing /health endpoint..."
HEALTH_RESPONSE=$(kubectl exec $BACKEND_POD -n $NAMESPACE -- wget -q -O- http://localhost:5000/health 2>&1 || echo "FAILED")

if [ "$HEALTH_RESPONSE" != "FAILED" ]; then
    echo "Health response:"
    echo "$HEALTH_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$HEALTH_RESPONSE"
    
    if echo "$HEALTH_RESPONSE" | grep -q "connected"; then
        echo -e "${GREEN}✅ Backend health check shows database connected${NC}"
    elif echo "$HEALTH_RESPONSE" | grep -q "disconnected"; then
        echo -e "${RED}❌ Backend health check shows database disconnected${NC}"
    fi
else
    echo -e "${RED}❌ Health endpoint not responding${NC}"
fi
echo ""

# TEST 9: Test API Endpoint
echo -e "${YELLOW}TEST 9: Backend API Endpoint${NC}"
echo "Testing /api/tasks endpoint..."
API_RESPONSE=$(kubectl exec $BACKEND_POD -n $NAMESPACE -- wget -q -O- http://localhost:5000/api/tasks 2>&1 || echo "FAILED")

if [ "$API_RESPONSE" != "FAILED" ]; then
    echo "API response:"
    echo "$API_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$API_RESPONSE"
    echo -e "${GREEN}✅ API endpoint responding${NC}"
else
    echo -e "${RED}❌ API endpoint not responding${NC}"
fi
echo ""

# TEST 10: Check for Previous Container Logs (if restarted)
if [ "$RESTARTS" -gt 0 ]; then
    echo -e "${YELLOW}TEST 10: Previous Container Logs (from crash)${NC}"
    kubectl logs $BACKEND_POD -n $NAMESPACE --previous --tail=50 2>/dev/null || echo "No previous logs available"
    echo ""
fi

# SUMMARY
echo "════════════════════════════════════════════════════════"
echo "DIAGNOSIS SUMMARY"
echo "════════════════════════════════════════════════════════"
echo ""

# Determine issue
if [ "$ENDPOINT_COUNT" -eq 0 ]; then
    echo -e "${RED}🔴 ISSUE: MongoDB service has no endpoints${NC}"
    echo "Fix: Check MongoDB deployment and pod status"
elif ! kubectl exec $BACKEND_POD -n $NAMESPACE -- timeout 3 wget -q -O- mongodb-service:27017 &>/dev/null; then
    echo -e "${RED}🔴 ISSUE: Backend cannot reach MongoDB${NC}"
    echo "Fix: Check network policies or service configuration"
elif kubectl logs $BACKEND_POD -n $NAMESPACE --tail=100 | grep -iq "authentication failed"; then
    echo -e "${RED}🔴 ISSUE: MongoDB authentication failed${NC}"
    echo "Fix: Check MONGO_URI credentials match MongoDB Secret"
elif [ "$HEALTH_RESPONSE" = "FAILED" ]; then
    echo -e "${RED}🔴 ISSUE: Backend not responding${NC}"
    echo "Fix: Check backend logs for application errors"
elif echo "$HEALTH_RESPONSE" | grep -q "disconnected"; then
    echo -e "${RED}🔴 ISSUE: Backend running but not connected to DB${NC}"
    echo "Fix: Check MONGO_URI environment variable and connection code"
else
    echo -e "${GREEN}✅ Backend appears healthy${NC}"
    echo "If frontend still fails, check frontend → backend connectivity"
fi

echo ""
echo "RECOMMENDED ACTIONS:"
echo "1. Review backend logs above for specific errors"
echo "2. Verify MONGO_URI format and credentials"
echo "3. Check that backend code uses correct env var names"
echo "4. Test MongoDB connection manually from backend pod"
echo ""
echo "Commands to try:"
echo "  kubectl logs $BACKEND_POD -n $NAMESPACE -f"
echo "  kubectl exec -it $BACKEND_POD -n $NAMESPACE -- sh"
echo "  kubectl describe pod $BACKEND_POD -n $NAMESPACE"
echo ""
