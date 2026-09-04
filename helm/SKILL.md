---
name: helm
description: Helm chart conventions, security, and validation rules. Use when authoring, editing, or reviewing Helm charts, templates, or values.yaml.
license: MIT
---

## Rules

- Values over templates. Document every key in values.yaml.
- Flag deprecated API versions and state which Kubernetes version they break on.
- `required` on mandatory values, `default` on optional ones.
- Never hardcode secrets in values.yaml or templates. Reference external secrets (ESO, Vault, CSI).
- Validate with `helm lint` and `helm template` before claiming work is done.

# Helm Charts Skill

## Quick Validation

```bash
# Lint the chart
helm lint ./mychart

# Template to verify output
helm template mychart ./mychart --values values.yaml

# Dry run install
helm install --dry-run --debug mychart ./mychart

# Package the chart
helm package ./mychart
```

## Chart Structure

```
mychart/
├── Chart.yaml
├── values.yaml
├── README.md
├── .helmignore
└── templates/
    ├── _helpers.tpl
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml
    ├── configmap.yaml
    └── NOTES.txt
```

## Chart.yaml Best Practices

```yaml
apiVersion: v2
name: my-application
description: A Helm chart for my application
type: application
version: 1.0.0
appVersion: "1.0.0"
keywords:
  - myapp
home: https://github.com/myorg/myapp
sources:
  - https://github.com/myorg/myapp
maintainers:
  - name: Your Name
    email: your.email@example.com
dependencies:
  - name: postgresql
    version: "12.x.x"
    repository: "https://charts.bitnami.com/bitnami"
    condition: postgresql.enabled
```

## values.yaml Structure

```yaml
# Global settings
global:
  imageRegistry: ""
  storageClass: ""

# Application settings
replicaCount: 3

image:
  repository: myapp
  tag: latest
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: false
  className: nginx
  hosts:
    - host: myapp.example.com
      paths:
        - path: /
          pathType: Prefix

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

# Security
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000

# Probes
livenessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: http
  initialDelaySeconds: 5
  periodSeconds: 5
```

## Template Best Practices

### Use Helper Functions
```yaml
# templates/_helpers.tpl
{{- define "mychart.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

# Use in templates
metadata:
  name: {{ include "mychart.fullname" . }}
```

### Conditional Resources
```yaml
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "mychart.fullname" . }}
# ...
{{- end }}
```

## Pre-Deploy Checklist

- [ ] Chart passes `helm lint`
- [ ] Template renders correctly (`helm template`)
- [ ] Values are documented in README.md
- [ ] Resource limits are set
- [ ] Security contexts are configured
- [ ] Health checks (liveness/readiness) defined
- [ ] No hardcoded secrets (use Secrets or external secret management)
- [ ] NOTES.txt provides useful post-install info

## Debugging

```bash
# Get detailed template output
helm template mychart . --debug

# Check with different values
helm template mychart . -f values-staging.yaml

# Validate against cluster
helm install --dry-run --debug mychart .
```
