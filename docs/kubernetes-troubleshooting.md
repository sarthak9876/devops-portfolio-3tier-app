# Kubernetes Troubleshooting Guide

## Common Errors and Solutions

### Error 1: ImagePullBackOff

**Symptom:**
```
NAME                     READY STATUS           RESTARTS AGE
backend-5d6f8b9c7d-abc12 0/1   ImagePullBackOff 0        2m
```

**Cause:** Cannot pull Docker image from ECR

**Debugging:**
```
kubectl describe pod <pod-name>
``

# Look for:
# Failed to pull image "123456789012.dkr.ecr.ap-south-1.amazonaws.com/taskmaster-backend:latest":
# rpc error: code = Unknown desc = Error response from daemon: 
# pull access denied for 123456789012.dkr.ecr.ap-south-1.amazonaws.com/taskmaster-backend, 
# repository does not exist or may require 'docker login'

Solutions:

Check ECR repository exists:

bash
aws ecr describe-repositories --region ap-south-1 | grep taskmaster
Verify image was pushed:

bash
aws ecr list-images --repository-name taskmaster-backend --region ap-south-1
Check IAM permissions (node role needs ECR access):

```
# Node role should have AmazonEC2ContainerRegistryReadOnly policy
aws iam list-attached-role-policies --role-name taskmaster-dev-eks-node-role
```
If permissions are correct but still failing:

```
# Re-push image
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-south-1.amazonaws.com
docker push <account-id>.dkr.ecr.ap-south-1.amazonaws.com/taskmaster-backend:latest
```
Error 2: CrashLoopBackOff
Symptom:

text
NAME                        READY   STATUS             RESTARTS   AGE
backend-5d6f8b9c7d-abc12    0/1     CrashLoopBackOff   5          5m
Cause: Container starts but immediately exits

Debugging:

```
# View container logs
kubectl logs <pod-name>

# View previous container logs (if restarted)
kubectl logs <pod-name> --previous
```
# Common errors in logs:
# - MongoDB connection failed
# - Missing environment variables
# - Port already in use
# - Syntax errors in code
Solutions:

Check environment variables:

```
kubectl exec <pod-name> -- env
```

# Verify all required vars are set:
# - MONGO_URI
# - NODE_ENV
# - PORT
Test MongoDB connectivity from backend pod:

```bash
kubectl exec -it <backend-pod> -- sh
apk add curl
curl mongodb-service:27017
```
# Should return: "It looks like you are trying to access MongoDB over HTTP..."
Check application health endpoint:

```bash
kubectl port-forward <pod-name> 5000:5000
curl http://localhost:5000/health
```
Error 3: Pending Pods
Symptom:

text
NAME                        READY   STATUS    RESTARTS   AGE
backend-5d6f8b9c7d-abc12    0/1     Pending   0          10m
Cause: Scheduler cannot place pod on any node

Debugging:

```bash
kubectl describe pod <pod-name>
```
# Look for events:
# Warning  FailedScheduling  5s (x10 over 10m)  default-scheduler  
# 0/2 nodes are available: 2 Insufficient cpu.
Common causes:

Insufficient resources:

```bash
# Check node resources
kubectl top nodes
kubectl describe nodes
```
# Solution: Scale node group or reduce resource requests
Node selectors/taints:

```bash
# Check if pod has nodeSelector that doesn't match any node
kubectl get pod <pod-name> -o yaml | grep -A 5 nodeSelector

# Check node taints
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
```
Volume binding issues:

```bash
# Check PVC status
kubectl get pvc
# If Pending, check storageclass exists
kubectl get storageclass
```
Error 4: Service Not Accessible
Symptom: Cannot access service from outside cluster

Debugging:

Check service exists:

```bash
kubectl get svc frontend-loadbalancer

# Should show:
# NAME                    TYPE           EXTERNAL-IP                          PORT(S)
# frontend-loadbalancer   LoadBalancer   a1b2c3-1234.elb.ap-south-1.aws.com   80:30123/TCP
```
Check LoadBalancer provisioning:

```
bash
kubectl describe svc frontend-loadbalancer
```
# Look for events:
# Normal   EnsuringLoadBalancer   2m   service-controller  Ensuring load balancer
# Normal   EnsuredLoadBalancer    1m   service-controller  Ensured load balancer

# If stuck, check AWS console for errors
Check security groups:
```
bash
# Get security group from LoadBalancer
LB_NAME=$(kubectl get svc frontend-loadbalancer -o jsonpath='{.status.loadBalancer.ingress.hostname}' | cut -d'-' -f1)
aws elbv2 describe-load-balancers --region ap-south-1 | grep $LB_NAME -A 10
```
# Check security group allows inbound 80/443
Test connectivity:

```
bash
# From within cluster
kubectl run test-pod --rm -it --image=busybox -- sh
wget -O- http://frontend-service:3000

# From outside (via LoadBalancer)
LB_URL=$(kubectl get svc frontend-loadbalancer -o jsonpath='{.status.loadBalancer.ingress.hostname}')
curl http://$LB_URL
```
Error 5: MongoDB Authentication Failed
Symptom: Backend logs show:

text
MongoServerError: Authentication failed
Solutions:

Verify secret is correct:

```bash
# Decode secret
kubectl get secret taskmaster-secrets -o jsonpath='{.data.MONGO_ROOT_PASSWORD}' | base64 -d
echo # add newline
```
# Should match password in ConfigMap
Check MongoDB initialization:

```bash
kubectl logs <mongodb-pod>
```
# Should see:
# "Successfully added user: { "user" : "admin", ... }"
Re-create MongoDB with fresh data:

```bash
kubectl delete pod -l app=mongodb
```
# Pod will restart with emptyDir (fresh data)
Error 6: Readiness Probe Failed
Symptom:

text
Readiness probe failed: HTTP probe failed with statuscode: 500
Debugging:

```bash
# Check health endpoint manually
kubectl exec -it <pod-name> -- curl http://localhost:5000/health

# View recent logs
kubectl logs <pod-name> --tail=50
```
# Common causes:
# - Database not ready yet (increase initialDelaySeconds)
# - Health endpoint returns 500 (fix app code)
# - Wrong port in probe (check containerPort matches)
Solution:

```
# Adjust readinessProbe timing
readinessProbe:
  httpGet:
    path: /health
    port: 5000
  initialDelaySeconds: 30  # Increase this
  periodSeconds: 10
  failureThreshold: 3
Error 7: OOMKilled (Out of Memory)
Symptom:
```
```
NAME                        READY   STATUS      RESTARTS   AGE
backend-5d6f8b9c7d-abc12    0/1     OOMKilled   3          10m
Cause: Container exceeded memory limit
```
Debugging:

```bash
kubectl describe pod <pod-name>

# Last State:
#   Terminated:
#     Reason:       OOMKilled
#     Exit Code:    137

# Check memory usage before crash
kubectl top pod <pod-name>
```
Solution:

```
# Increase memory limits
resources:
  limits:
    memory: "512Mi"  # Was 256Mi
```
Debugging Workflow
1. Quick Status Check
```bash
kubectl get all -n taskmaster-dev
kubectl get events --sort-by='.lastTimestamp' -n taskmaster-dev
```
2. Pod-Level Debugging
```bash
# Describe pod (events, status)
kubectl describe pod <pod-name>
```
# View logs
```
kubectl logs <pod-name>
kubectl logs <pod-name> --previous  # Previous container instance
kubectl logs <pod-name> -c <container-name>  # Multi-container pod
```
# Shell into running container
```
kubectl exec -it <pod-name> -- /bin/sh
```
# Port forward for testing
```
kubectl port-forward <pod-name> 8080:5000
```
3. Service-Level Debugging
```bash
# Check endpoints (pods behind service)
kubectl get endpoints backend-service
```
# Should show pod IPs:
# NAME              ENDPOINTS                         AGE
# backend-service   10.0.1.45:5000,10.0.1.67:5000     5m

# If empty, selector doesn't match any pods
```
kubectl get pods --show-labels
```
4. Network Debugging
```bash
# Create debug pod
kubectl run debug --rm -it --image=nicolaka/netshoot -- bash

# Inside debug pod:
nslookup backend-service.taskmaster-dev.svc.cluster.local
curl http://backend-service.taskmaster-dev.svc.cluster.local:5000/health
```
Prevention Strategies (Senior DevOps Best Practices)
1. Resource Management
```
# Always set requests and limits
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"
```
2. Health Checks
text
# Use all three probes
startupProbe: {}   # For slow-starting apps
livenessProbe: {}  # Restart if unhealthy
readinessProbe: {} # Remove from service if not ready
3. Graceful Shutdown
```
# Give app time to finish requests
spec:
  terminationGracePeriodSeconds: 30
```
4. Pod Disruption Budgets
```
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: backend-pdb
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: backend
```
5. Resource Quotas
```
apiVersion: v1
kind: ResourceQuota
metadata:
  name: taskmaster-quota
  namespace: taskmaster-dev
spec:
  hard:
    requests.cpu: "2"
    requests.memory: "4Gi"
    limits.cpu: "4"
    limits.memory: "8Gi"
    pods: "10"
```
Interview Questions Based on These Errors
```
Q: Pod is in CrashLoopBackOff. How do you troubleshoot?

A:

Check logs: kubectl logs <pod> --previous

Describe pod for events: kubectl describe pod <pod>

Verify env vars: kubectl exec <pod> -- env

Check health endpoint: kubectl port-forward <pod> 8080:5000

Review application code for errors

Check dependencies (DB, external APIs)
```
```
Q: LoadBalancer service stuck in Pending. What could be wrong?

A:

Check AWS IAM permissions for EKS node role

Verify VPC has internet gateway (public subnet)

Check AWS service limits (ELB quota)

Review security groups

Check CloudFormation stack for errors (K8s creates CF stack for LB)
```
```
Q: How do you debug DNS resolution issues in Kubernetes?

A:

Check CoreDNS pods: kubectl get pods -n kube-system | grep coredns

Test DNS from pod: kubectl exec <pod> -- nslookup kubernetes.default

Check service exists: kubectl get svc <service-name>

Verify endpoints: kubectl get endpoints <service-name>

Check network policies blocking DNS (port 53)

```
