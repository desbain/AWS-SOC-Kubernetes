#!/bin/bash
# =============================================================================
# setup-eks-cluster.sh
# AWS-SOC-Kubernetes | Provision the EKS cluster using eksctl
# Prerequisites: eksctl, kubectl, AWS CLI configured as SOC_Admin
# Usage: bash scripts/setup-eks-cluster.sh
# =============================================================================

set -euo pipefail

CLUSTER_NAME="soc-eks-cluster"
REGION="us-east-2"
NODE_TYPE="t3.medium"
NODE_COUNT=2
K8S_VERSION="1.32"

echo "======================================================"
echo " AWS-SOC-Kubernetes | EKS Cluster Provisioning"
echo "======================================================"

echo ""
echo "[1/4] Verifying prerequisites..."
command -v eksctl >/dev/null 2>&1 || { echo "eksctl not found. Install: https://eksctl.io"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found."; exit 1; }
aws sts get-caller-identity --query 'Arn' --output text

echo ""
echo "[2/4] Creating EKS cluster: $CLUSTER_NAME in $REGION"
echo "      This takes approximately 15-20 minutes..."

eksctl create cluster \
  --name "$CLUSTER_NAME" \
  --region "$REGION" \
  --version "$K8S_VERSION" \
  --nodegroup-name soc-workers \
  --node-type "$NODE_TYPE" \
  --nodes "$NODE_COUNT" \
  --nodes-min 1 \
  --nodes-max 3 \
  --managed \
  --asg-access \
  --full-ecr-access \
  --alb-ingress-access \
  --with-oidc \
  --tags "Project=AWS-SOC,Environment=dev,ManagedBy=eksctl"

echo ""
echo "[3/4] Updating kubeconfig..."
aws eks update-kubeconfig \
  --region "$REGION" \
  --name "$CLUSTER_NAME"

echo ""
echo "[4/4] Creating IRSA role for Fluent Bit (CloudWatch log shipping)..."
# IRSA = IAM Roles for Service Accounts
# The fluent-bit pod gets a projected token exchanged for temp AWS credentials
# Scoped to CloudWatchAgentServerPolicy only — no static keys on disk

eksctl create iamserviceaccount \
  --name fluent-bit \
  --namespace soc-system \
  --cluster "$CLUSTER_NAME" \
  --region "$REGION" \
  --attach-policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy \
  --approve \
  --override-existing-serviceaccounts

echo ""
echo "======================================================"
echo " EKS Cluster Ready"
echo "======================================================"
echo ""
echo "Cluster: $CLUSTER_NAME"
echo "Region:  $REGION"
kubectl get nodes -o wide
echo ""
echo "Next: bash scripts/deploy.sh"
