---
name: terraform
description: Terraform/IaC conventions, security, and formatting rules. Use when writing, editing, or reviewing Terraform code (.tf/.tfvars), modules, or infrastructure-as-code.
license: MIT
---

## Rules

- Modules over monoliths. Remote state always, with locking. No hardcoded regions or account IDs.
- Variables need descriptions. Tag all resources with environment, owner, team.
- Use data sources instead of hardcoded ARNs/IDs.
- Validate with `terraform validate` and `tflint` before claiming work is done.
- Security scan with `tfsec` or `checkov` on any IAM or networking changes.
- `terraform fmt` runs automatically on every edit.
- Encryption and logging enabled by default, not opt-in.
