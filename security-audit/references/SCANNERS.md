# Scanners

Automated scanners produce leads, not findings. Every hit still has to pass the candidate gate in `SKILL.md`: name the principal, the boundary and a concrete result, or drop it (or file it as a hardening note). Use only tools that are already installed. Scanners read source and lockfiles; they do not execute the target, so they need no sandbox. Never run them against deployed endpoints.

## Multi-language

```bash
semgrep --config=auto .                  # also: p/security-audit, p/owasp-top-ten
trivy fs --scanners vuln,secret,misconfig .
osv-scanner -r .                          # lockfile CVEs across ecosystems
```

## Per ecosystem

| Ecosystem | SAST | Dependencies |
|---|---|---|
| Python | `bandit -r . -ll` | `pip-audit` |
| Go | `gosec ./...` | `govulncheck ./...` |
| JS/TS | `eslint` with `eslint-plugin-security` | `npm audit --audit-level=moderate` |
| Rust | `cargo clippy` | `cargo audit` |
| Terraform/K8s/Helm | `checkov -d .`, `trivy config .` | (n/a) |

A CVE in the dependency tree counts only when source reaches the vulnerable function with lower-trust input. Otherwise report it as an upgrade note.

## Secrets

```bash
gitleaks detect --source . --log-opts="--all"   # includes history
trufflehog git file://. --only-verified
```

| Type | Pattern |
|---|---|
| AWS access key | `AKIA[0-9A-Z]{16}` |
| GitHub token | `gh[pousr]_[A-Za-z0-9]{36}` |
| Slack token | `xox[baprs]-` |
| Stripe live key | `sk_live_[A-Za-z0-9]{24}` |
| Private key | `-----BEGIN .*PRIVATE KEY-----` |
| JWT | `eyJ[A-Za-z0-9_-]*\.eyJ` |

Before reporting a match, confirm that it is a live credential and not a placeholder, test fixture or public key ID. Never print the value: give the file, line and type. A secret committed to history is compromised even after deletion, so the remediation is **rotate first**, then purge history (`git filter-repo`), then prevent recurrence (a gitleaks pre-commit hook). On this home setup, secrets live behind the `secrets` skill.
