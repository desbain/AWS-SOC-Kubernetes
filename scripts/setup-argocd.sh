#!/bin/bash
# =============================================================================
# setup-argocd.sh
# AWS-SOC-Kubernetes | Install ArgoCD onto the EKS cluster and bootstrap
# the SOC Application so GitOps sync begins immediately
#
# What ArgoCD does in this project:
# Instead of running `helm install` manually, you push a change to your Git
# repo and ArgoCD detects it, diffs the cluster state against the desired
# state in Git, and applies the delta automatically. Your Git repo becomes
# the single source of truth for the cluster — no manual kubectl or helm
# commands needed after initial setup.
#
# Prerequisites: kubectl configured for EKS, helm installed
# Usage: bash scripts/setup-argocd.sh
# =============================================================================

set -euo pipefail

ARGOCD_NAMESPACE="argocd"
ARGOCD_VERSION="v2.10.0"
SOC_NAMESPACE="soc-system"

echo "======================================================"
echo " AWS-SOC-Kubernetes | ArgoCD Bootstrap"
echo "======================================================"

echo ""
echo "[1/6] Creating ArgoCD namespace..."
kubectl create namespace "$ARGOCD_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "[2/6] Installing ArgoCD $ARGOCD_VERSION..."
kubectl apply -n "$ARGOCD_NAMESPACE" \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/install.yaml"

echo ""
echo "[3/6] Waiting for ArgoCD server to be ready (up to 3 minutes)..."
kubectl rollout status deployment/argocd-server -n "$ARGOCD_NAMESPACE" --timeout=180s

echo ""
echo "[4/6] Applying ArgoCD Project (soc-project)..."
kubectl apply -f argocd/projects/soc-project.yaml

echo ""
echo "[5/6] Applying ArgoCD Application (soc-stack)..."
kubectl apply -f argocd/applications/soc-stack-app.yaml

echo ""
echo "[6/6] Retrieving initial admin password..."
ARGOCD_PASSWORD=$(kubectl -n "$ARGOCD_NAMESPACE" get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)

echo ""
echo "======================================================"
echo " ArgoCD is ready"
echo "======================================================"
echo ""
echo " Access the UI:"
echo "   kubectl port-forward svc/argocd-server -n $ARGOCD_NAMESPACE 8080:443"
echo "   Then open: https://localhost:8080"
echo ""
echo " Login credentials:"
echo "   Username: admin"
echo "   Password: $ARGOCD_PASSWORD"
echo ""
echo " Change the password immediately after first login:"
echo "   argocd account update-password"
echo ""
echo " The soc-stack Application will now auto-sync from your Git repo."
echo " Every push to the configured branch triggers a cluster reconciliation."
echo "======================================================"
