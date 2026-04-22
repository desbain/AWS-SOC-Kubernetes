#!/bin/bash
# =============================================================================
# simulate-attack.sh
# AWS-SOC-Kubernetes | Threat simulation against the SOC victim pod
# Equivalent to Phase 4 in the baseline AWS-SOC project
# Usage: bash scripts/simulate-attack.sh
# =============================================================================

set -euo pipefail

NAMESPACE="soc-system"
VICTIM_POD="soc-victim-pod"
ATTACKER_IMAGE="ubuntu:24.04"

echo "======================================================"
echo " AWS-SOC-Kubernetes Attack Simulation"
echo "======================================================"

echo ""
echo "[TEST 1] SSH Brute Force — triggers Fluent Bit metric filter"
echo "         Runs 10 failed SSH attempts against soc-victim-pod"
echo "         Watch CloudWatch SOC-Auth-Logs and Falco alerts"

kubectl run attacker \
  --image="$ATTACKER_IMAGE" \
  --namespace="$NAMESPACE" \
  --restart=Never \
  --rm \
  -it \
  -- /bin/bash -c '
    apt-get update -qq && apt-get install -y openssh-client -qq
    for i in $(seq 1 10); do
      echo "Attempt $i..."
      ssh -o StrictHostKeyChecking=no \
          -o ConnectTimeout=3 \
          -o PasswordAuthentication=yes \
          fakeuser@soc-victim-service 2>/dev/null || true
      sleep 2
    done
    echo "Brute force simulation complete."
  '

echo ""
echo "[TEST 2] Shell in Container — triggers Falco SOC Shell in Container rule"
echo "         This has NO equivalent in the VM-based SOC — K8s native threat"
echo ""
echo "         Exec into soc-victim-pod and spawn bash..."
kubectl exec -n "$NAMESPACE" "$VICTIM_POD" -- /bin/bash -c \
  'echo "Shell spawned — Falco should have detected this syscall"'

echo ""
echo "[TEST 3] Check Falco caught the alerts..."
sleep 5
echo "Recent Falco alerts:"
kubectl logs -n "$NAMESPACE" -l app=falco --tail=30 | grep -E "(SOC|Warning|Critical|Error)" || true

echo ""
echo "[TEST 4] Check Fluent Bit shipped the auth.log events..."
echo "Recent Fluent Bit logs:"
kubectl logs -n "$NAMESPACE" -l app=fluent-bit --tail=20 | grep -E "(soc.auth|auth.log|flush)" || true

echo ""
echo "======================================================"
echo " Simulation complete."
echo " Verify in CloudWatch: SOC-Auth-Logs should show failed SSH events"
echo " Verify in Falco logs: SOC Shell in Container rule should have fired"
echo "======================================================"
