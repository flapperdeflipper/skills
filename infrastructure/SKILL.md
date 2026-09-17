---
name: infrastructure
description: "Infrastructure as code and cloud: Terraform/OpenTofu (modules, tests, CI, state ops), Helm charts, Kubernetes manifests/Kustomize/EKS/GKE/AKS/OpenShift, and AWS/Azure/GCP architecture, migration, cost and DR. Use when writing, reviewing or debugging .tf, charts, manifests, or cloud designs."
---

# Infrastructure

Router. Read only the guide the task needs: `<guide>/GUIDE.md` in this skill's directory. `terraform` and `kubernetes` are large: their guides index a `references/` tree (paths relative to the guide). Read the one reference your task needs, never the tree.

| Guide | Read when |
|---|---|
| `terraform` | `.tf`/`.tfvars`, modules, tests, CI, scans, state operations; diagnose the failure mode first |
| `helm` | Authoring, editing or reviewing charts, templates or `values.yaml` |
| `kubernetes` | Manifests, Kustomize, managed clusters; insecure defaults, starvation, exposure, rollouts, API drift |
| `cloud-architect` | Cloud topology, migrations, cost optimization, disaster recovery, Well-Architected reviews |

Secrets follow the `secrets` skill. Commit and deploy checklists are `workflow` in `dev-workflow`.
