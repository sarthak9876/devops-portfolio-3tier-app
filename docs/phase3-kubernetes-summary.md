# Phase 3: Kubernetes Deployment - Summary

## Completion Date
January 17, 2026

## Objectives Achieved
✅ Deployed 3-tier application to AWS EKS
✅ Implemented nginx reverse proxy pattern
✅ Created production-ready Kubernetes manifests
✅ Configured health checks and probes
✅ Implemented secrets management
✅ Documented troubleshooting procedures

## Architecture Overview
```
┌─────────────────────────────────────────────────────────────────┐
│ PRODUCTION ARCHITECTURE                                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ Internet                                                        │
│ │                                                               │ 
│ ▼                                                               │
│ AWS NLB (LoadBalancer)                                          │
│ │                                                               │ 
│ ▼                                                               │
│ Frontend Pods (3 replicas)                                      │
│ ├── nginx (serves React SPA)                                    │
│ └── reverse proxy (/api/* → backend-service)                    │
│ │                                                               │
│ ▼                                                               │
│ Backend Pods (2 replicas)                                       │
│ └── Node.js API (/api/v1/tasks)                                 │ 
│ │                                                               │
│ ▼                                                               │
│ MongoDB Pod (1 replica)                                         │ 
│ └── Persistent data (emptyDir in dev, PVC in prod)              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```
text

## Key Metrics
- **Pods Running**: 6 (3 frontend + 2 backend + 1 mongodb)
- **Services**: 4 (1 LoadBalancer + 3 ClusterIP)
- **Deployment Time**: ~5 minutes
- **Cost**: ~$16/month (single LoadBalancer)

## Kubernetes Resources

### Namespace
- `taskmaster-dev`: Isolated environment for development

### ConfigMap
- Non-sensitive configuration (NODE_ENV, ports, etc.)

### Secret
- MongoDB credentials (MONGO_URI)
- Base64 encoded, injected as environment variables

### Deployments
1. **Frontend**: 3 replicas, nginx:1.27-alpine
2. **Backend**: 2 replicas, node:20-alpine
3. **MongoDB**: 1 replica, mongo:7.0

### Services
1. **frontend-loadbalancer**: LoadBalancer (public access)
2. **frontend-service**: ClusterIP (internal)
3. **backend-service**: ClusterIP (internal)
4. **mongodb-service**: ClusterIP (internal)

## Health Check Endpoints
- `/health`: Liveness probe (is app alive?)
- `/ready`: Readiness probe (is app ready for traffic?)
- `/nginx-health`: Nginx status for frontend pods

## Resource Allocation

### Frontend Pods
- Requests: 64Mi RAM, 50m CPU
- Limits: 128Mi RAM, 100m CPU

### Backend Pods
- Requests: 128Mi RAM, 100m CPU
- Limits: 256Mi RAM, 200m CPU

### MongoDB Pod
- Requests: 256Mi RAM, 250m CPU
- Limits: 512Mi RAM, 500m CPU

## Security Measures
1. **Secrets Management**: K8s Secrets for credentials
2. **Network Isolation**: Backend/DB not publicly exposed
3. **RBAC**: Namespace-level access control
4. **Security Headers**: Helmet middleware in backend
5. **Input Validation**: Mongoose schema validation

## Testing Results
✅ All pods running and healthy
✅ Health checks passing (liveness + readiness)
✅ API endpoints responding correctly
✅ Frontend UI accessible via LoadBalancer
✅ Database persistence working
✅ Nginx reverse proxy routing correctly
✅ Rolling updates work without downtime

## Interview Talking Points

### Question: "Walk me through your Kubernetes architecture"
**Answer**: "I deployed a 3-tier application with frontend (React + nginx), backend (Node.js API), and MongoDB database. The frontend uses nginx as a reverse proxy—browser requests to /api/* get proxied to the backend service within the cluster. This gives me same-origin requests (no CORS issues), keeps the backend internal for security, and uses only one LoadBalancer to save costs."

### Question: "How do you handle secrets?"
**Answer**: "I use Kubernetes Secrets with base64 encoding for MongoDB credentials. The secret is mounted as an environment variable (MONGO_URI) that the backend reads at runtime. I'm aware this is only base64, not encrypted—in production I'd enable encryption at rest with AWS KMS or use AWS Secrets Manager with the External Secrets Operator."

### Question: "What happens if a pod crashes?"
**Answer**: "Kubernetes automatically restarts it. I have liveness probes that check /health every 10 seconds. If 3 consecutive checks fail, K8s kills and restarts the pod. Readiness probes ensure pods aren't added to the service until they're actually ready to handle traffic."

### Question: "How do you deploy updates?"
**Answer**: "I use rolling updates. With maxSurge=1 and maxUnavailable=0, Kubernetes creates new pods with the updated image, waits for them to pass readiness checks, then terminates old pods one at a time. This ensures zero downtime during deployments."

## Lessons Learned

### What Worked Well
- Nginx reverse proxy eliminated VITE_API_URL build-time complexity
- Health checks caught issues before they affected users
- Resource limits prevented noisy neighbor problems
- Comprehensive logging helped debug issues quickly

### Challenges Faced
1. **VITE_API_URL confusion**: Initially tried build-time env vars, switched to reverse proxy
2. **Module not found error**: Backend structure mismatch, consolidated to single file
3. **DNS resolution**: Browser can't reach K8s internal DNS, needed proxy
4. **Image pull timing**: Added startup probes for slow-starting containers

### What I'd Do Differently
- Would implement Ingress Controller (AWS ALB) for path-based routing
- Would use StatefulSet + PVC for MongoDB in production
- Would implement Horizontal Pod Autoscaler (HPA) for auto-scaling
- Would add monitoring from day 1 (Prometheus + Grafana)

## Cost Analysis
- **EKS Control Plane**: $73/month (0.10/hour)
- **EC2 Nodes**: ~$60/month (2x t3.medium)
- **LoadBalancer**: $16/month (NLB)
- **EBS Volumes**: $8/month (80GB gp3)
- **Total**: ~$157/month

Optimization opportunities:
- Use Fargate for serverless pods ($0 when not running)
- Implement cluster autoscaler (scale nodes to 0 off-hours)
- Use spot instances for non-critical workloads (70% cost savings)

## Next Phase Preview: Monitoring

### Phase 4 Objectives
- Deploy Prometheus for metrics collection
- Deploy Grafana for visualization
- Create custom dashboards
- Set up alerting rules
- Monitor pod health, resource usage, API latency

### Metrics to Track
- Pod CPU/memory usage
- API request rate and latency
- Error rate (4xx, 5xx responses)
- MongoDB connection pool stats
- Container restart counts

## Resources
- [Kubernetes Manifests](../kubernetes/manifests/)
- [Troubleshooting Guide](kubernetes-troubleshooting.md)
- [Dockerfile - Frontend](../application/frontend/Dockerfile)
- [Dockerfile - Backend](../application/backend/Dockerfile)
- [Nginx Config](../application/frontend/nginx.conf)

## Completion Checklist
- [x] EKS cluster created and configured
- [x] kubectl access configured
- [x] Namespace created
- [x] ConfigMap and Secrets created
- [x] All deployments healthy
- [x] Services exposing pods correctly
- [x] LoadBalancer provisioned
- [x] Health checks passing
- [x] API endpoints functional
- [x] Frontend UI accessible
- [x] Documentation completed
- [x] Code committed to Git
- [x] Git tag created (v1.0.0-phase3)

**Status**: ✅ COMPLETE - Ready for Phase 4 (Monitoring)
