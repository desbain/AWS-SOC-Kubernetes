#!/bin/bash
# =============================================================================
# teardown.sh
# AWS-SOC-Kubernetes | Clean teardown of all K8s resources and EKS cluster
# WARNING: This deletes everything. Run only when you are done.
# Usage: bash scripts/teardown.sh
# =============================================================================

set -euo pipefail

CLUSTER_NAME="soc-eks-cluster"
REGION="eu-north-1"
NAMESPACE="soc-system"

echo "======================================================"
echo " AWS-SOC-Kubernetes Teardown"
echo " WARNING: This will delete all resources and the EKS cluster"
echo "======================================================"
echo ""
read -rp "Are you sure? Type YES to confirm: " CONFIRM
[[ "$CONFIRM" != "YES" ]] && echo "Aborted." && exit 0

echo ""
echo "[1/3] Deleting all Kubernetes resources in soc-system..."
kubectl delete namespace "$NAMESPACE" --ignore-not-found=true

echo ""
echo "[2/3] Deleting IRSA service account..."
eksctl delete iamserviceaccount \
  --name fluent-bit \
  --namespace "$NAMESPACE" \
  --cluster "$CLUSTER_NAME" \
  --region "$REGION" || true

echo ""
echo "[3/3] Deleting EKS cluster (takes ~10 minutes)..."
eksctl delete cluster \
  --name "$CLUSTER_NAME" \
  --region "$REGION"

echo ""
echo "Teardown complete. All resources deleted."
echo "Note: CloudWatch Log Groups (SOC-Auth-Logs, VPC-Flow-Logs) are retained."
echo "      Delete them manually in the console if needed."
