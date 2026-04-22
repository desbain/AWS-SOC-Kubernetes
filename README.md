# AWS-SOC-Kubernetes: Container-Native Security Operations on EKS

**Portfolio Pillar:** Cloud Security | Container Security | Kubernetes | GitOps
**Status:** Complete
**Author:** [George Awa] | Cybersecurity Analyst | SOC Engineer
**Platform:** AWS EKS (Elastic Kubernetes Service)
**Kubernetes Version:** 1.29
**Deployment:** Raw Manifests → Helm Chart → ArgoCD GitOps

> This project re-architects the [AWS-SOC](../AWS-SOC/README.md) detection pipeline
> for a container-native environment. The VM-based CloudWatch Agent is replaced by
> Fluent Bit. The CloudWatch Metric Filter is augmented by Falco — a runtime threat
> detection engine that intercepts kernel syscalls using eBPF before log lines are
> even written. The entire stack is packaged as a Helm chart and delivered via
> ArgoCD GitOps — Git is the single source of truth for cluster state.

---

## The Core Architectural Shift

| Capability | AWS-SOC (VM) | AWS-SOC-Kubernetes |
|---|---|---|
| Log shipping agent | CloudWatch Agent (systemd service) | Fluent Bit (DaemonSet) |
| Detection engine | CloudWatch Metric Filter (text pattern) | Falco (eBPF kernel syscalls) |
| Detection timing | After log line is written | At syscall — before the log exists |
| Host | EC2 Ubuntu VM | EKS node + victim Pod |
| IAM credentials | Instance Profile | IRSA (no static keys anywhere) |
| Attack surface | Single EC2 host | Multi-node cluster + pod attack surface |
| Threat scope | SSH brute force | SSH + shell + privilege escalation + log tampering |
| MITRE ATT&CK tagging | Manual (OSINT post-incident) | Automatic (Falco rule tags) |
| Deployment method | Manual AWS console | Helm chart + ArgoCD GitOps auto-sync |
| Config drift protection | None | ArgoCD selfHeal reverts manual changes |

---

## Architecture

```
[Attack Attempt]
      |
      ├── SSH brute force → [soc-victim-pod] ──────────────────────────────────┐
      │                           |                                             │
      │                    /var/log/auth.log                                    │
      │                           |                                             │
      │                    [Fluent Bit DaemonSet]                               │
      │                           |                                             │
      │                    [CloudWatch: SOC-Auth-Logs]                          │
      │                           |                                             │
      │                    [Metric Filter: FailedPasswordCount]                 │
      │                           |                                             │
      │                    [CloudWatch Alarm: SOC-Brute-Force-Alert]            │
      │                           |                                             │
      └── Shell in container ─────┤                                             │
      └── Syscall events ─────────┤                                             │
                                  │                                             │
                           [Falco DaemonSet]                                    │
                           (eBPF kernel probe)                                  │
                                  │                                             │
                           [Falco Alerts — MITRE tagged]                        │
                                  │                                             │
                           [SNS: SOC-Alert-Notification] ◄──────────────────────┘
                                  │
                           [Analyst Inbox]

─────────────────────────────────────────────────────────────────
GitOps Layer (ArgoCD)
─────────────────────────────────────────────────────────────────

[Git Repo: main branch]
      │
      │  git push
      ▼
[ArgoCD: watches repo every 3 minutes]
      │
      │  diff: desired state (Git) vs actual state (cluster)
      ▼
[ArgoCD syncs Helm chart to EKS cluster]
      │
      │  selfHeal: reverts any manual kubectl drift automatically
      ▼
[soc-system namespace — always matches Git]
```

---

## Repository Structure

```
AWS-SOC-Kubernetes/
│
├── README.md
├── .gitignore
│
├── manifests/                          # Raw manifests (deploy with --raw flag)
│   ├── namespace/namespace.yaml
│   ├── rbac/rbac.yaml
│   ├── configmaps/
│   │   ├── fluent-bit-configmap.yaml
│   │   └── falco-configmap.yaml
│   ├── daemonsets/
│   │   ├── fluent-bit-daemonset.yaml
│   │   └── falco-daemonset.yaml
│   └── deployments/
│       ├── soc-victim-pod.yaml
│       └── cloudwatch-exporter-deployment.yaml
│
├── helm/                               # Helm chart — parameterised deployment
│   ├── values-prod.yaml                # Production overrides
│   └── soc-stack/
│       ├── Chart.yaml                  # Chart metadata + upstream dependencies
│       ├── values.yaml                 # All configurable defaults
│       └── templates/
│           ├── _helpers.tpl            # Shared label/name helpers
│           ├── NOTES.txt               # Post-install output (printed by Helm)
│           ├── namespace.yaml
│           ├── rbac.yaml
│           ├── fluent-bit-configmap.yaml
│           ├── falco-configmap.yaml
│           ├── fluent-bit-daemonset.yaml
│           ├── falco-daemonset.yaml
│           └── soc-victim-pod.yaml
│
├── argocd/                             # GitOps layer
│   ├── projects/
│   │   └── soc-project.yaml            # AppProject — scopes repo + namespace access
│   └── applications/
│       ├── soc-stack-app.yaml          # Dev Application — auto-sync enabled
│       └── soc-stack-app-prod.yaml     # Prod Application — manual sync only
│
├── scripts/
│   ├── setup-eks-cluster.sh            # Provision EKS + IRSA with eksctl
│   ├── setup-argocd.sh                 # Install ArgoCD + bootstrap Applications
│   ├── deploy.sh                       # --raw | --helm | --argocd deployment modes
│   ├── simulate-attack.sh              # Brute force + shell-in-container tests
│   └── teardown.sh                     # Clean cluster + resource deletion
│
└── screenshots/
    └── README.md                       # Screenshot naming guide (23 captures)
```

---

## Prerequisites

- AWS CLI configured as `SOC_Admin`
- `eksctl` installed ([eksctl.io](https://eksctl.io))
- `kubectl` installed
- `helm` >= 3.12 installed
- The [AWS-SOC](../AWS-SOC/README.md) CloudWatch alarms and SNS topic already deployed

---

## Step 1 — Provision the EKS Cluster

```bash
bash scripts/setup-eks-cluster.sh
```

This creates a 2-node managed EKS cluster in `eu-north-1` and sets up IRSA so Fluent Bit can ship to CloudWatch without any static credentials. Takes approximately 15–20 minutes.

---

## Step 2 — Deploy the SOC Stack

Three deployment modes — pick one:

### Mode A: Raw Manifests (baseline understanding)

```bash
bash scripts/deploy.sh --raw
```

Applies all manifests in dependency order using `kubectl apply`. Good for understanding each component before introducing Helm abstraction.

---

### Mode B: Helm Chart (parameterised, rollback-capable)

```bash
# Pull upstream Fluent Bit and Falco chart dependencies
helm dependency update helm/soc-stack

# Preview what will be deployed without touching the cluster
helm upgrade --install soc-stack helm/soc-stack \
  --values helm/soc-stack/values.yaml \
  --namespace soc-system --create-namespace \
  --dry-run

# Deploy dev environment
bash scripts/deploy.sh --helm

# Deploy prod environment (victim pod off, tighter thresholds)
helm upgrade --install soc-stack helm/soc-stack \
  --values helm/values-prod.yaml \
  --namespace soc-system --wait --atomic

# Roll back if something goes wrong
helm rollback soc-stack 1 -n soc-system
```

**What `--atomic` does:** If any resource fails to become healthy, Helm rolls back automatically. No broken partial state left in the cluster.

---

### Mode C: ArgoCD GitOps (recommended — production grade)

```bash
bash scripts/deploy.sh --argocd
```

This installs ArgoCD, creates the `soc-project` AppProject (namespace + repo scoping), and applies the `soc-stack` Application which begins auto-syncing immediately.

**After bootstrap — the GitOps workflow:**

```bash
# Make any change to the Helm chart or values
vim helm/soc-stack/values.yaml

git add helm/soc-stack/values.yaml
git commit -m "raise brute force threshold to 5"
git push origin main

# ArgoCD detects the change within 3 minutes and applies it automatically
# Monitor in real time:
kubectl get applications -n argocd -w
```

**Access the ArgoCD UI:**

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open: https://localhost:8080  |  Username: admin
# Password:
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

**Manual sync for prod:**

```bash
kubectl apply -f argocd/applications/soc-stack-app-prod.yaml
argocd app sync soc-stack-prod   # Human reviews diff then approves
```

---

## Step 3 — Verify Each Layer

```bash
# All pods running
kubectl get pods -n soc-system -o wide

# Fluent Bit shipping to CloudWatch
kubectl logs -n soc-system -l app=fluent-bit --tail=30
# Look for: [output:cloudwatch_logs] flushing chunk

# Falco rules loaded
kubectl logs -n soc-system -l app=falco --tail=30
# Look for: Loading rules from file /etc/falco/rules.d/soc_rules.yaml

# CloudWatch receiving logs
# AWS Console → CloudWatch → Log groups → SOC-Auth-Logs
# Should show streams named: eks-node-<node-name>

# ArgoCD application healthy (if using Mode C)
kubectl get application soc-stack -n argocd
# STATUS should show: Synced | Healthy
```

---

## Step 4 — Simulate Attacks

```bash
bash scripts/simulate-attack.sh
```

**Test 1 — SSH Brute Force:** 10 failed SSH attempts from an attacker pod → Fluent Bit ships auth.log → CloudWatch alarm fires → SNS pushes to analyst inbox. MTTD under 60 seconds.

**Test 2 — Shell in Container:** `kubectl exec` spawns bash inside `soc-victim-pod` → Falco intercepts the `execve` syscall at the kernel level → `SOC Shell in Container` rule fires before any log line is written.

---

## Helm Chart Reference

### Key Values

| Value | Default | Description |
|---|---|---|
| `global.awsRegion` | `eu-north-1` | AWS region for CloudWatch |
| `global.environment` | `dev` | Tag applied to all resources |
| `fluentbit.enabled` | `true` | Deploy Fluent Bit DaemonSet |
| `falco.enabled` | `true` | Deploy Falco DaemonSet |
| `falco.customRules.enabled` | `true` | Load the 5 custom SOC rules |
| `falco.output.priority` | `WARNING` | Minimum alert severity |
| `socVictim.enabled` | `true` | Deploy attack target pod (off in prod) |
| `detection.failedSshThreshold` | `3` | Failed SSH attempts before alarm |
| `detection.thresholdPeriod` | `60` | Evaluation window in seconds |

### Overriding Individual Values

```bash
# Raise threshold inline without editing values.yaml
helm upgrade soc-stack helm/soc-stack --reuse-values \
  --set detection.failedSshThreshold=5

# Disable victim pod inline
helm upgrade soc-stack helm/soc-stack --reuse-values \
  --set socVictim.enabled=false
```

---

## ArgoCD Reference

### AppProject (`argocd/projects/soc-project.yaml`)

The AppProject enforces security boundaries on what ArgoCD can do:

| Control | Value |
|---|---|
| Trusted source repos | Your GitHub repo + upstream Helm chart repos only |
| Allowed destinations | `soc-system` namespace only — cannot touch `kube-system` |
| Orphaned resource monitoring | Warns when cluster has resources not tracked in Git |
| `soc-engineer` role | Read-only + manual sync permission for non-admin team members |

### Application Settings (`argocd/applications/soc-stack-app.yaml`)

| Setting | Enabled | Reason |
|---|---|---|
| `automated.prune` | Yes | Removes resources deleted from Git |
| `automated.selfHeal` | Yes | Reverts manual `kubectl` drift |
| `automated.allowEmpty` | No | Prevents accidental namespace wipe |
| `ApplyOutOfSyncOnly` | Yes | Only touches resources that actually changed |
| `PruneLast` | Yes | New resources become healthy before old ones are removed |

### Dev vs Prod

| Setting | Dev | Prod |
|---|---|---|
| Sync | Automatic | Manual (human approval) |
| Victim pod | Enabled | Disabled |
| Falco priority | `WARNING` | `ERROR` |
| Auth log retention | 90 days | 365 days |
| Revision history | 10 | 20 |

---

## The Five SOC Falco Detection Rules

| Rule | Threat | MITRE Tactic | Equivalent in AWS-SOC |
|---|---|---|---|
| SOC SSH Brute Force Attempt | Repeated failed SSH auth | Credential Access | CloudWatch Metric Filter |
| SOC Shell in Container | bash/sh spawned in container | Execution | **No equivalent — K8s native** |
| SOC Sudo in Container | sudo inside a container | Privilege Escalation | **No equivalent — K8s native** |
| SOC Unexpected Outbound Connection | Process beaconing from soc-system | Command & Control | **No equivalent — K8s native** |
| SOC Audit Log File Modified | auth.log / syslog tampered | Defense Evasion | CloudTrail integrity validation |

Three of the five rules are only detectable at the container and kernel level — they have no equivalent in the VM-based SOC project.

---

## Key Engineering Decisions

**Why Helm over raw manifests?**
Raw manifests are static. Helm templates parameterise everything — the same chart deploys to dev and prod with different values. The chart is versioned and rollback-capable. Helm also handles resource dependency ordering that raw `kubectl apply -f` doesn't guarantee.

**Why ArgoCD over a CI/CD `helm upgrade` step?**
A CI/CD pipeline that runs `helm upgrade` on push is push-based — if the pipeline fails silently or someone runs `kubectl delete daemonset falco` manually, the cluster drifts with no detection. ArgoCD is pull-based with continuous reconciliation. It detects drift between Git and the live cluster every 3 minutes regardless of whether a pipeline ran. `selfHeal: true` means your Falco DaemonSet cannot be silently disabled.

**Why manual sync for prod?**
Production changes need a human to review the ArgoCD diff before applying. Auto-sync in prod risks pushing a breaking change the moment it lands on `main`. The prod Application enforces an explicit approval gate.

**Why IRSA instead of an Instance Profile for EKS pods?**
An Instance Profile grants permissions to every pod on the node. IRSA binds permissions to a specific Kubernetes ServiceAccount using OIDC federation — only the `fluent-bit` ServiceAccount can call CloudWatch. All other pods on the same nodes are denied even if they're compromised.

**Why `selfHeal: true` matters for security?**
An attacker who gains cluster access might delete the Falco DaemonSet to disable runtime detection before executing their next move. With `selfHeal: true`, ArgoCD detects the missing DaemonSet within 3 minutes and restores it. Detection coverage cannot be silently disabled via `kubectl`.

---

## Teardown

```bash
bash scripts/teardown.sh
```

> EKS clusters run continuously and will incur cost. Always tear down when done testing.
> CloudWatch Log Groups are retained after teardown — they persist in the shared pipeline from the baseline AWS-SOC project.

---

## Related Projects

| Project | Description |
|---|---|
| [AWS-SOC](../AWS-SOC/README.md) | Manual build — the baseline this project extends |
| [AWS-SOC-Terraform](../AWS-SOC-Terraform/README.md) | IaC codification of the manual SOC pipeline |
