#!/bin/bash
# =============================================================================
# deploy.sh
# AWS-SOC-Kubernetes | Deployment script
#
# Two deployment modes:
#   --raw      Apply raw manifests directly (no Helm, no ArgoCD)
#   --helm     Deploy via Helm chart (manual, no GitOps)
#   --argocd   Bootstrap ArgoCD and let it manage the Helm chart (GitOps)
#
# Usage:
#   bash scripts/deploy.sh --raw      # Phase 1 validation
#   bash scripts/deploy.sh --helm     # Helm-managed deployment
#   bash scripts/deploy.sh --argocd   # Full GitOps setup (recommended)
# =============================================================================

set -euo pipefail

NAMESPACE="soc-system"
RELEASE_NAME="soc-stack"
CHART_PATH="./helm/soc-stack"
VALUES_FILE="./helm/soc-stack/values.yaml"
MODE="${1:---helm}"

echo "======================================================"
echo " AWS-SOC-Kubernetes Deployment — Mode: $MODE"
echo "======================================================"

case "$MODE" in

  --raw)
    echo ""
    echo "Deploying raw Kubernetes manifests..."
    kubectl apply -f manifests/namespace/namespace.yaml
    kubectl apply -f manifests/rbac/rbac.yaml
    kubectl apply -f manifests/configmaps/fluent-bit-configmap.yaml
    kubectl apply -f manifests/configmaps/falco-configmap.yaml
    kubectl apply -f manifests/deployments/soc-victim-pod.yaml
    kubectl apply -f manifests/daemonsets/fluent-bit-daemonset.yaml
    kubectl apply -f manifests/daemonsets/falco-daemonset.yaml
    kubectl apply -f manifests/deployments/cloudwatch-exporter-deployment.yaml

    echo ""
    echo "Waiting for DaemonSets to be ready..."
    kubectl rollout status daemonset/fluent-bit -n "$NAMESPACE" --timeout=120s
    kubectl rollout status daemonset/falco -n "$NAMESPACE" --timeout=120s
    ;;

  --helm)
    echo ""
    echo "Deploying via Helm chart..."

    echo "[1/3] Updating Helm dependencies (Fluent Bit + Falco charts)..."
    helm dependency update "$CHART_PATH"

    echo "[2/3] Running helm upgrade --install..."
    helm upgrade --install "$RELEASE_NAME" "$CHART_PATH" \
      --values "$VALUES_FILE" \
      --namespace "$NAMESPACE" \
      --create-namespace \
      --wait \
      --timeout 5m \
      --atomic

    echo "[3/3] Helm release status:"
    helm status "$RELEASE_NAME" -n "$NAMESPACE"
    ;;

  --argocd)
    echo ""
    echo "Setting up ArgoCD GitOps pipeline..."
    bash scripts/setup-argocd.sh
    echo ""
    echo "ArgoCD is now managing the soc-stack deployment."
    echo "Future changes: push to Git → ArgoCD auto-syncs the cluster."
    ;;

  *)
    echo "Unknown mode: $MODE"
    echo "Usage: bash scripts/deploy.sh [--raw|--helm|--argocd]"
    exit 1
    ;;

esac

echo ""
echo "======================================================"
echo " Deployment complete"
echo "======================================================"
echo ""
echo "Pod status:"
kubectl get pods -n "$NAMESPACE" -o wide

echo ""
echo "Next: bash scripts/simulate-attack.sh"
