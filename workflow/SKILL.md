---
name: workflow
description: Pre-commit and pre-deploy checklists for Python, Terraform, and Helm projects. Use when preparing a commit or working through a deployment checklist.
license: MIT
---

# DevOps Development Workflow

## Complete Workflow for Python + Terraform + Helm Projects

### Starting a New Feature

1. **Create a branch**
   ```bash
   git checkout -b feature/my-feature
   ```

2. **Make changes**. The `python`, `terraform`, `helm`, `kubernetes`, `bash-scripting`
   and `buildroot` skills load on demand and carry the conventions.

3. **Review** with `/tf-review`, `/helm-review`, `/k8s-review`, `/docker-review` or
   `/sec-review`, depending on what changed.

4. **Commit**
   ```bash
   git add .
   git commit -m "feat: add new feature"
   ```

### Before Every Commit

Run this checklist:

```bash
# Python specific
ruff check .
ruff format .
mypy .
pytest

# Terraform specific  
terraform fmt -recursive
terraform validate
tflint

# Helm specific
helm lint ./charts/*
helm template ./charts/* | less
```

### Deployment Checklist

For Terraform:
- [ ] Run `terraform plan` and review output
- [ ] Check state lock status
- [ ] Verify backend configuration
- [ ] Confirm environment variables set
- [ ] Get approval for changes
- [ ] Run `terraform apply`

For Helm:
- [ ] Chart version bumped
- [ ] Values tested in staging
- [ ] helm lint passes
- [ ] Dry-run shows expected output
- [ ] Rollback plan documented

## Useful Aliases

Add to your shell:

```bash
# Python
alias pyfmt='ruff format . && ruff check .'
alias pytype='mypy .'
alias pytestw='pytest -v --tb=short'

# Terraform
alias tfv='terraform validate'
alias tfp='terraform plan'
alias tff='terraform fmt -recursive'

# Helm
alias hl='helm lint'
alias ht='helm template'
```

## MCP Server Usage

Once configured, opencode can:

- **terraform MCP**: Get provider docs, search modules, validate configs against registry
- **filesystem MCP**: Safely read/write files without full system access  
- **git MCP**: Analyze commit history, check diffs, find related changes
- **github MCP**: Create PRs, review issues, fetch PR comments
