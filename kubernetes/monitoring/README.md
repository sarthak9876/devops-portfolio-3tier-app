# Kubernetes Monitoring Stack

This directory contains the configuration and deployment files for a comprehensive Kubernetes monitoring stack based on the **kube-prometheus-stack** Helm chart. The monitoring stack provides full observability for the TaskMaster application running on AWS EKS.

## 🏗️ Architecture Overview

The monitoring stack consists of the following components:

### Core Components
- **Prometheus**: Metrics collection and storage system
- **Grafana**: Visualization and dashboard platform
- **AlertManager**: Alert routing and notification management
- **Prometheus Operator**: Manages Prometheus, AlertManager, and related monitoring components

### Metrics Collectors
- **Node Exporter**: Collects system-level metrics from cluster nodes
- **Kube State Metrics**: Generates metrics about Kubernetes objects (pods, deployments, services, etc.)
- **cAdvisor**: Collects container metrics (integrated with kubelet)

### Storage
- **AWS EBS CSI Driver**: Provides persistent storage for Prometheus and Grafana data
- **GP3 Storage Class**: Optimized EBS storage class with encryption and expansion support

## 📊 What Gets Monitored

### Infrastructure Metrics
- Node CPU, memory, disk, and network usage
- Kubernetes cluster health and performance
- Persistent volume usage and status
- Container resource consumption

### Application Metrics
- Pod lifecycle events and status
- Service discovery and endpoint health
- Deployment rollout status and replica counts
- Custom application metrics (when instrumented)

### Alerting Rules
- Node down/unhealthy
- Pod crashes and restarts
- High resource utilization
- Storage issues
- Kubernetes API server availability
- Network connectivity problems

## 📁 Directory Structure

```
monitoring/
├── README.md                           # This documentation
├── values-monitoring-template.yaml     # Template configuration file
├── current-values.yaml                 # Current deployed configuration
├── storageclass-gp3.yaml               # AWS EBS GP3 storage class
├── ebs-csi-driver-policy.json          # IAM policy for EBS CSI driver
├── trust-policy.json                   # IAM trust policy for service account
└── trust-policy-fixed.json            # Updated trust policy
```

## 🚀 Deployment Instructions

### Prerequisites

1. **AWS EKS Cluster**: Running Kubernetes cluster with OIDC provider configured
2. **kubectl**: Configured to access your EKS cluster
3. **Helm 3**: Package manager for Kubernetes
4. **AWS CLI**: For AWS resource management

### Step 1: Configure AWS IAM (One-time Setup)

#### Create EBS CSI Driver IAM Role

```bash
# Create the IAM policy for EBS CSI driver
aws iam create-policy \
  --policy-name TaskMaster-EBS-CSI-Driver-Policy \
  --policy-document file://ebs-csi-driver-policy.json

# Create IAM role with OIDC trust relationship
aws iam create-role \
  --role-name TaskMaster-EBS-CSI-Driver-Role \
  --assume-role-policy-document file://trust-policy-fixed.json

# Attach the policy to the role
aws iam attach-role-policy \
  --role-name TaskMaster-EBS-CSI-Driver-Role \
  --policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/TaskMaster-EBS-CSI-Driver-Policy
```

#### Install EBS CSI Driver

```bash
# Add AWS EBS CSI driver Helm repository
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm repo update

# Install EBS CSI driver
helm upgrade --install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
  --namespace kube-system \
  --set controller.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="arn:aws:iam::YOUR_ACCOUNT_ID:role/TaskMaster-EBS-CSI-Driver-Role"
```

### Step 2: Deploy Storage Class

```bash
# Deploy the GP3 storage class
kubectl apply -f storageclass-gp3.yaml
```

### Step 3: Configure Monitoring Values

```bash
# Copy the template to create your values file
cp values-monitoring-template.yaml values-monitoring.yaml

# Edit the values file to customize:
# - Grafana admin password (CHANGE_ME_TO_SECURE_PASSWORD)
# - Slack webhook URLs for alerting
# - External labels for your environment
# - Resource limits based on your cluster size
vim values-monitoring.yaml
```

### Step 4: Deploy Monitoring Stack

```bash
# Add Prometheus community Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create monitoring namespace (if not exists)
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Install kube-prometheus-stack
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values values-monitoring.yaml \
  --wait
```

### Step 5: Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n monitoring

# Check services
kubectl get svc -n monitoring

# Check persistent volumes
kubectl get pvc -n monitoring
```

## 🔗 Accessing Monitoring Services

### Grafana (Visualization)
```bash
# Port forward Grafana to localhost
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80

# Access at: http://localhost:3000
# Default credentials:
# Username: admin
# Password: AdminPassword123! (or your configured password)
```

### Prometheus (Metrics)
```bash
# Port forward Prometheus to localhost
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090

# Access at: http://localhost:9090
```

### AlertManager (Alerting)
```bash
# Port forward AlertManager to localhost
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-alertmanager 9093:9093

# Access at: http://localhost:9093
```

## 📈 Default Dashboards

The monitoring stack comes pre-configured with several useful dashboards:

### Grafana Dashboards
1. **Kubernetes Cluster Monitoring** (ID: 7249)
   - Cluster overview with nodes, pods, and resource usage
   - API server metrics and etcd performance

2. **Node Exporter Full** (ID: 1860)
   - Detailed node metrics including CPU, memory, disk, and network
   - System-level monitoring for all cluster nodes

3. **Persistent Volumes** (ID: 13646)
   - Storage usage and performance metrics
   - Volume status and capacity monitoring

### Accessing Dashboards
1. Open Grafana at http://localhost:3000
2. Login with admin credentials
3. Navigate to the "Default" folder in the left sidebar
4. Click on any dashboard to view metrics

## 🔔 Alerting Configuration

### Pre-configured Alerts
- **Node Down**: Triggers when a node becomes unreachable
- **Pod Crash**: Alerts on frequent pod restarts
- **High CPU/Memory Usage**: Resource utilization thresholds
- **Storage Issues**: Disk space and volume problems
- **Kubernetes API Issues**: Control plane availability

### Alert Routing
Alerts are configured to route through different channels:
- **Critical**: Immediate notification (Slack integration ready)
- **Warning**: Warning-level alerts (Slack integration ready)
- **Default**: Fallback routing

### Configuring Slack Integration
1. Create Slack webhook URLs for your channels
2. Update `values-monitoring.yaml`:
```yaml
alertmanager:
  config:
    global:
      slack_api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
    receivers:
    - name: 'slack-critical'
      slack_configs:
      - channel: '#critical-alerts'
        title: 'Critical Alert'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
```

## ⚙️ Configuration Customization

### Scaling for Production
Adjust resource requests/limits in `values-monitoring.yaml`:

```yaml
prometheus:
  prometheusSpec:
    resources:
      requests:
        cpu: 1000m  # Increase for larger clusters
        memory: 4Gi
      limits:
        cpu: 2000m
        memory: 8Gi

grafana:
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 1000m
      memory: 2Gi
```

### Retention Settings
```yaml
prometheus:
  prometheusSpec:
    retention: 30d  # Increase for longer data retention
    retentionSize: "50GB"
```

### High Availability
For production clusters with multiple nodes:
```yaml
prometheus:
  prometheusSpec:
    replicas: 2

alertmanager:
  alertmanagerSpec:
    replicas: 2
```

## 🔧 Troubleshooting

### Common Issues

#### Persistent Volume Issues
```bash
# Check PVC status
kubectl get pvc -n monitoring

# Check PV status
kubectl get pv

# Check EBS CSI driver logs
kubectl logs -n kube-system deployment/aws-ebs-csi-driver
```

#### Grafana Login Issues
```bash
# Reset Grafana admin password
kubectl exec -n monitoring deployment/monitoring-grafana -- grafana-cli admin reset-admin-password YOUR_NEW_PASSWORD
```

#### Prometheus Not Scraping Metrics
```bash
# Check Prometheus targets
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
# Visit http://localhost:9090/targets
```

#### High Resource Usage
```bash
# Check resource usage
kubectl top pods -n monitoring
kubectl top nodes

# Adjust resource limits in values-monitoring.yaml and redeploy
helm upgrade monitoring prometheus-community/kube-prometheus-stack -n monitoring -f values-monitoring.yaml
```

## 🧹 Cleanup

To remove the monitoring stack:

```bash
# Uninstall Helm release
helm uninstall monitoring -n monitoring

# Remove namespace
kubectl delete namespace monitoring

# Remove storage class (optional)
kubectl delete -f storageclass-gp3.yaml

# Remove IAM resources (optional)
aws iam detach-role-policy --role-name TaskMaster-EBS-CSI-Driver-Role --policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/TaskMaster-EBS-CSI-Driver-Policy
aws iam delete-role --role-name TaskMaster-EBS-CSI-Driver-Role
aws iam delete-policy --policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/TaskMaster-EBS-CSI-Driver-Policy
```

## 📚 Additional Resources

- [kube-prometheus-stack Documentation](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [AlertManager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [AWS EBS CSI Driver](https://github.com/kubernetes-sigs/aws-ebs-csi-driver)

## ❓ Questions?

If you have any questions about the monitoring setup or need assistance with configuration, please check:

1. The troubleshooting section above
2. Kubernetes logs for specific components
3. Prometheus/AlertManager configuration validation
4. AWS IAM and EBS permissions

---

**Note**: This monitoring stack is configured for the TaskMaster application running on AWS EKS. Adjust resource limits and retention settings based on your cluster size and monitoring requirements.
