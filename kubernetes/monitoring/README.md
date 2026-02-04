# Monitoring Stack - Prometheus + Grafana

## Overview

This directory contains the configuration for our production-grade monitoring stack using the `kube-prometheus-stack` Helm chart.

**Components:**
- **Prometheus**: Time-series database and metrics collection
- **Grafana**: Visualization and dashboards
- **Alertmanager**: Alert routing and notifications
- **kube-state-metrics**: Kubernetes cluster state metrics
- **node-exporter**: Hardware and OS metrics
- **Prometheus Operator**: Manages Prometheus instances via CRDs

## Architecture
```
┌─────────────────────────────────────────────────────────┐
│ Monitoring Namespace 					  │
├─────────────────────────────────────────────────────────┤
│ 							  │
│ Prometheus Server ──────┐ 				  │
│ ↓ scrapes 	      │				          │
│ ┌─────────────────┐ │ 				  |
│ │ Application     │ │  				  │
│ │ Metrics         │ │ 				  │
│ │ (Backend API)   │ │ 				  │
│ └─────────────────┘ │ 				  │
│ │                   					  │
│ ┌─────────────────┐ │ 				  │
│ │ kube-state      │────┘ 				  │
│ │ metrics         │ 					  │
│ └─────────────────┘ 					  │
│ │ 		      					  │
│ ┌─────────────────┐ │ 				  │
│ │ node-exporter   │────┘ 				  │
│ │ (DaemonSet)     │					  │
│ └─────────────────┘ 					  │
│ │ 							  │
│ ▼ 							  │
│ ┌─────────────────┐         ┌──────────────────┐ 	  │
│ │ Alertmanager    │────────▶│ Slack / Email    │	  │
│ └─────────────────┘         └──────────────────┘ 	  │
│ │                        				  │
│ ▼ queries                                               │
│ ┌─────────────────┐                                     │
│ │ Grafana         │◀──── User Browser                   │
│ │ (Dashboards)    │                                     │
│ └─────────────────┘                                     │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Prerequisites

1. **EKS Cluster** with OIDC provider enabled
2. **EBS CSI Driver** installed (for persistent volumes)
3. **StorageClass** (gp3) configured as default
4. **Helm 3.x** installed
5. **kubectl** configured with cluster access

## Installation

### 1. Install EBS CSI Driver (if not already installed)

```bash
# Install EBS CSI Driver as EKS addon
aws eks create-addon \
  --cluster-name taskmaster-eks-dev \
  --addon-name aws-ebs-csi-driver \
  --service-account-role-arn arn:aws:iam::YOUR_ACCOUNT_ID:role/AmazonEKS_EBS_CSI_DriverRole \
  --region us-east-1
```

2. Create StorageClass
```bash
kubectl apply -f storageclass-gp3.yaml
```
3. Configure Values File
```bash
# Copy template
cp values-monitoring-template.yaml values-monitoring.yaml
```
# Edit and update:
# - Grafana admin password
# - Slack webhook URL (optional)
# - Resource limits (based on your node capacity)
```bash
vim values-monitoring.yaml
```
4. Install Monitoring Stack
```bash
# Add Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```
# Install the stack
```bash
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values values-monitoring.yaml
```

# Watch installation
```bash
kubectl get pods -n monitoring --watch
Accessing Components
Prometheus
```
# Port-forward
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090

# Access: http://localhost:9090
Grafana
bash
# Port-forward
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80

# Access: http://localhost:3000
# Username: admin
# Password: (from values-monitoring.yaml)
Alertmanager
bash
# Port-forward
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-alertmanager 9093:9093

# Access: http://localhost:9093
Verification
bash
# Check all pods are running
kubectl get pods -n monitoring

# Check PVCs are bound
kubectl get pvc -n monitoring

# Check Prometheus targets
# Visit: http://localhost:9090/targets (after port-forward)

# Check Grafana data source
# Grafana UI → Configuration → Data Sources → Prometheus
Configuration Files
File	Description	Commit to Git?
values-monitoring-template.yaml	Template with placeholders	✅ Yes
values-monitoring.yaml	Actual config with secrets	❌ No (.gitignore)
storageclass-gp3.yaml	EBS gp3 StorageClass	✅ Yes
README.md	This file	✅ Yes
Cost Estimation
EBS Volumes (7 days):

Prometheus: 20 GiB × $0.08/GB/month × (7/30) = $0.37

Grafana: 5 GiB × $0.08/GB/month × (7/30) = $0.09

Alertmanager: 5 GiB × $0.08/GB/month × (7/30) = $0.09

Total storage cost: ~$0.55 for 1 week

Troubleshooting
PVC Pending
Issue: PVC stuck in Pending state

Solution:

bash
# Check if StorageClass exists
kubectl get storageclass

# Check EBS CSI driver is running
kubectl get pods -n kube-system | grep ebs-csi

# Check PVC events
kubectl describe pvc <pvc-name> -n monitoring
Pod CrashLoopBackOff
Issue: Prometheus/Grafana pods crashing

Solution:

bash
# Check pod logs
kubectl logs -n monitoring <pod-name>

# Check resource constraints
kubectl describe node
No Metrics in Grafana
Issue: Grafana shows "No data"

Solution:

bash
# Verify Prometheus is scraping
# Prometheus UI → Status → Targets (all should be UP)

# Check Grafana data source connection
# Grafana → Configuration → Data Sources → Prometheus → Test
Maintenance
Upgrade Monitoring Stack
bash
helm upgrade monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values values-monitoring.yaml
Backup Grafana Dashboards
bash
# Export dashboards via Grafana UI
# Dashboards → Manage → Export → Save JSON

# Or backup the entire PVC
kubectl exec -n monitoring monitoring-grafana-xxx -- tar czf /tmp/grafana-backup.tar.gz /var/lib/grafana
kubectl cp monitoring/monitoring-grafana-xxx:/tmp/grafana-backup.tar.gz ./grafana-backup.tar.gz
Uninstall
bash
# Delete Helm release
helm uninstall monitoring -n monitoring

# Delete PVCs (if you want to remove data)
kubectl delete pvc -n monitoring --all

# Delete namespace
kubectl delete namespace monitoring


Interview Talking Points
```text
Q: Why kube-prometheus-stack instead of standalone Prometheus?

"kube-prometheus-stack is a curated collection that includes Prometheus, Grafana, Alertmanager, and essential exporters pre-configured to work together. It uses the Prometheus Operator pattern, which allows me to define monitoring configurations as Kubernetes CRDs (ServiceMonitors, PodMonitors). This is much more maintainable than manually editing Prometheus config files—it's declarative and follows GitOps principles."
```

```text
Q: How do you handle Prometheus data retention?

"I set retention to 15 days with a 10GB size limit. For long-term storage in production, I'd use Thanos or Cortex for federated storage with S3 backend. Thanos gives me unlimited retention, multi-cluster querying, and downsampling for cost efficiency. But for this project, 15 days is sufficient for troubleshooting and demonstrating monitoring capabilities."
```

```text
Q: How do you monitor the monitoring stack itself?

"Meta-monitoring is critical. The stack includes self-monitoring via default rules—Prometheus monitors itself, Alertmanager monitors Prometheus, etc. I have alerts for Prometheus scrape failures, Alertmanager notification failures, and high resource usage. I'd also set up an external uptime monitor (like UptimeRobot) to ping Prometheus from outside the cluster."
```

Resources:

kube-prometheus-stack Chart

Prometheus Documentation

Grafana Documentation

PromQL Query Examples

AWS EBS CSI Driver

Next Steps:

 Configure Slack alerts (Part 4 - Alert Rules)

 Create custom application dashboards

 Set up recording rules for complex queries

 Implement ServiceMonitor for backend API

 Configure alert inhibition rules

 Set up Grafana OnCall for on-call rotation

