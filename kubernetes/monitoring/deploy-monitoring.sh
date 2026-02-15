#!/bin/bash

echo "Setting cluster name and aws region variable values"
echo ""
CLUSTER_NAME="taskmaster-dev-eks"
AWS_REGION="us-east-1"

echo "Issuing OIDC provider"
echo ""
OIDC_ISSUER=$(aws eks describe-cluster \
  --name "$CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --query "cluster.identity.oidc.issuer" \
  --output text)

echo "OIDC Issuer: $OIDC_ISSUER"

echo "Issuing OIDC ID"
echo ""
OIDC_ID=$(echo "$OIDC_ISSUER" | sed -e "s/^https:\/\/oidc\.eks\.$AWS_REGION\.amazonaws\.com\/id\///")
echo "OIDC ID: $OIDC_ID"
# Should show: FE8CCF9F39866956DC8E97B97A8678BB

echo "Check if OIDC provider exists in IAM"

echo ""
aws iam list-open-id-connect-providers --output json | jq -r '.OpenIDConnectProviderList[].Arn' | grep "$OIDC_ID"

echo "Checking eksctl installation"
echo ""
if command -v eksctl &> /dev/null
then
  echo "eksctl already installed"
  echo ""
  eksctl version
else
  echo "eksctl is not installed. proceeding with installation."
  curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
  sudo mv /tmp/eksctl /usr/local/bin

  if command -v eksctl &> /dev/null
  then
    echo "eksctl installed successfully"
  else
    echo "eksctl installation failed."
    exit 1
  fi
fi

echo "Now create the OIDC provider using eksctl(one command!)"
echo ""
eksctl utils associate-iam-oidc-provider \
  --cluster "$CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --approve
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Get OIDC provider URL (without https://)"
echo ""
OIDC_PROVIDER=$(echo "$OIDC_ISSUER" | sed -e "s/^https:\/\///")

echo "OIDC Provider: $OIDC_PROVIDER"
echo ""

echo "Create correct trust policy"
echo ""
cat > trust-policy-fixed.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/${OIDC_PROVIDER}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_PROVIDER}:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa",
          "${OIDC_PROVIDER}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF

echo "Update the IAM role's trust policy"
echo ""
aws iam update-assume-role-policy \
  --role-name AmazonEKS_EBS_CSI_DriverRole \
  --policy-document file://trust-policy-fixed.json

echo "Verify the trust policy was updated"
echo ""
aws iam get-role \
  --role-name AmazonEKS_EBS_CSI_DriverRole \
  --query 'Role.AssumeRolePolicyDocument' \
  --output json


ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/AmazonEKS_EBS_CSI_DriverRole"

aws eks create-addon \
  --cluster-name "$CLUSTER_NAME" \
  --addon-name aws-ebs-csi-driver \
  --service-account-role-arn "$ROLE_ARN" \
  --region "$AWS_REGION"

# Wait for addon to be ACTIVE
aws eks describe-addon \
  --cluster-name "$CLUSTER_NAME" \
  --addon-name aws-ebs-csi-driver \
  --region "$AWS_REGION" \
  --query 'addon.status' \
  --output text


echo "Delete EBS CSI controller pods (they'll restart automatically)"
echo ""
kubectl delete pods -n kube-system -l app=ebs-csi-controller



echo "Watch pods restart"
echo ""
kubectl get pods -n kube-system | grep ebs-csi

echo "Check service account has the role annotation"
echo ""
kubectl describe sa ebs-csi-controller-sa -n kube-system


echo "Check pod logs (should NO LONGER show OIDC errors)"
echo ""
kubectl logs -n kube-system -l app=ebs-csi-controller -c ebs-plugin --tail=50

echo "Check if StorageClass exists"
echo ""
kubectl get storageclass

echo "If NOT exists, create gp3 StorageClass"
echo ""
cat > storageclass-gp3.yaml << 'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
  encrypted: "true"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete
EOF

kubectl apply -f storageclass-gp3.yaml

echo "Verify"
echo ""
kubectl get storageclass

echo "Delete the stuck Grafana PVC"
echo ""
kubectl delete pvc monitoring-grafana -n monitoring

echo "Also delete stuck Prometheus and Alertmanager PVCs if they exist"
echo ""
kubectl get pvc -n monitoring

echo "Delete any with STATUS=Pending"
echo ""
kubectl delete pvc <pvc-name> -n monitoring

echo "Deploy Helm release to recreate PVCs"
echo ""
helm uninstall monitoring  --namespace monitoring
echo ""
helm install monitoring prometheus-community/kube-prometheus-stack  --namespace monitoring   --create-namespace  --values values-monitoring.yaml

echo "Or just restart the deployments/statefulsets"
echo ""
kubectl rollout restart deployment monitoring-grafana -n monitoring
kubectl rollout restart statefulset prometheus-monitoring-kube-prometheus-prometheus -n monitoring
kubectl rollout restart statefulset alertmanager-monitoring-kube-prometheus-alertmanager -n monitoring

# Watch PVCs get created and bound
kubectl get pvc -n monitoring 




echo "Setup done. Verification time"

echo "1. Check OIDC provider exists"
echo ""
aws iam list-open-id-connect-providers | grep "$OIDC_ID"
# Should return an ARN

echo "2. Check EBS CSI driver pods are healthy"
echo ""
kubectl get pods -n kube-system | grep ebs-csi
# All should be Running

echo "3. Check pod logs (no errors)"
echo ""
kubectl logs -n kube-system -l app=ebs-csi-controller -c ebs-plugin --tail=20
# Should show successful initialization, no OIDC errors

echo "4. Check StorageClass exists and is default"
echo ""
kubectl get storageclass
# Should show: gp3 (default)

echo "5. Check ALL PVCs are bound"
echo ""
kubectl get pvc -n monitoring
# All should show STATUS: Bound

echo "6. Check PVs were created"
echo ""
kubectl get pv
# Should show volumes with CLAIM: monitoring/<pvc-name>

echo "7. Check EBS volumes in AWS"
echo ""
aws ec2 describe-volumes \
  --filters "Name=tag:kubernetes.io/cluster/${CLUSTER_NAME},Values=owned" \
  --region "$AWS_REGION" \
  --query 'Volumes[*].[VolumeId,Size,State,VolumeType,Tags[?Key==`kubernetes.io/created-for/pvc/name`].Value|[0]]' \
  --output table

# Should show EBS volumes with names matching your PVCs

echo "8. Check ALL monitoring pods are Running"
echo ""
kubectl get pods -n monitoring

