# Screenshots Directory — AWS-SOC-Kubernetes

Capture these screenshots as you complete each phase.

## Phase 1 — EKS Cluster Setup
- 01-eksctl-cluster-created-nodes-ready.png
- 02-eks-cluster-console-active.png
- 03-irsa-fluent-bit-service-account-created.png
- 04-kubectl-get-nodes-output.png

## Phase 2 — Namespace and RBAC
- 05-soc-system-namespace-created.png
- 06-rbac-service-accounts-created.png
- 07-clusterroles-and-bindings-applied.png

## Phase 3 — Fluent Bit Deployment
- 08-fluent-bit-configmap-applied.png
- 09-fluent-bit-daemonset-running-all-nodes.png
- 10-cloudwatch-soc-auth-logs-eks-streams.png
- 11-fluent-bit-logs-shipping-confirmed.png

## Phase 4 — Falco Deployment
- 12-falco-configmap-applied.png
- 13-falco-daemonset-running-all-nodes.png
- 14-falco-ebpf-probe-loaded.png
- 15-falco-custom-rules-active.png

## Phase 5 — Threat Simulation
- 16-attacker-pod-brute-force-running.png
- 17-falco-ssh-brute-force-alert-fired.png
- 18-falco-shell-in-container-alert-fired.png
- 19-cloudwatch-auth-logs-eks-failed-ssh-events.png
- 20-cloudwatch-alarm-triggered-from-eks.png
- 21-sns-email-alert-from-eks-environment.png

## Phase 6 — Comparison Evidence
- 22-side-by-side-vm-vs-k8s-detection-latency.png
- 23-falco-mitre-tagged-alerts-overview.png
