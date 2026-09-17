---
name: security-audit
description: "Security guidance and vulnerability review for codebases, APIs, services, CLIs, libraries, infra and agents: source-first, boundary-and-result evidence, calibrated severity, smallest fix. Use for security questions, focused reviews, secret/dependency scans, audits or pen tests. Full six-phase audit only on explicit request."
license: MIT
metadata:
  source: https://github.com/cloudflare/security-audit-skill
---

# Security Audit

Find vulnerabilities that violate a real trust boundary, then give owners the source evidence, safe reproduction, priority, and smallest effective fix. This is a defensive, source-first workflow. A candidate without a concrete affected principal, resource, or security outcome is not a confirmed finding.

## Operating modes

This skill is guidance by default. Loading it does not authorize the complete audit workflow or file creation.

- **Guidance mode**: For security questions, focused reviews, methodology, triage, or investigation of specific findings, use only the relevant parts of this skill. Do not automatically run all six phases, create an output directory, or write audit artifacts. You may launch focused agents when useful; they return results to the current task.
- **Full audit mode**: Use the complete workflow when the user explicitly asks to audit or pen-test a codebase, asks for a full, comprehensive, or end-to-end security review, or requests report artifacts. Read [references/FULL-AUDIT.md](references/FULL-AUDIT.md), run all six phases, and write the files it defines.

If the request could mean either mode, ask one focused question before creating files or starting the complete workflow.

## Universal execution safety

These rules apply in both operating modes. Source inspection is read-only. Run target-controlled builds, tests, processes, browsers, emulators, fuzzers, and fixture processing only inside an OS-enforced sandbox that provides all of these controls:

- no external network; use only an isolated loopback namespace when the check needs local client/server traffic;
- an empty environment populated from an explicit allowlist with safe values, with scratch-local `HOME`, temporary directories, and caches;
- a read-only target and toolchain, with the target-controlled process able to write only inside its assigned `scratch/` directory; and
- explicit low CPU, memory, process, file-size, disk, and wall-clock limits.

The agent, outside the target-controlled process, may make a disposable source copy in an assigned `scratch/` directory when a build must write beside source. In guidance mode, do not retain target-controlled files. In full audit mode, only trusted parent-side code may promote the minimum non-secret result to retained `artifacts/` using the promotion procedure in `references/FULL-AUDIT.md`. Never expose a retained output directory (other than the agent's own assigned `scratch/`), another agent's directory, the host home directory, credentials, sockets, or shared services to target code. Do not install dependencies or let builds fetch them. Use only tools and dependencies already available locally. If every control cannot be enforced, do not execute target code: report the missing sandbox capability as a needs-validation blocker and give a safe validation plan.

Use dummy principals, fixtures, and secrets. Do not probe deployed endpoints, external services, shared infrastructure, production identities, other users' data, or live control planes. Do not test availability against a live or shared process, publish artifacts, alter releases, spend paid API quota, or continue beyond the minimum local effect needed to establish a defect. If the decisive fact is outside source or the sandboxed fixture, report it as needing validation.

## Core principles

### Require a boundary and result

For every candidate, name the lower-trust principal, accepted input or action, intended control, crossed boundary, affected principal or resource, and concrete observed or owner-observable result. Do not elevate a missing best practice, guessed deployment behavior, generic parser crash, or self-impact into a security finding.

### Use bounded local evidence

Static analysis establishes the source path. Sandboxed local tests resolve behavior when all execution controls are available: a minimal function harness, existing unit test, small parser fixture, dummy-tenant integration test, locally rendered configuration, or bounded isolated-loopback client. Stop at a wrong return value, unauthorized dummy record, sanitizer finding, policy difference, or other minimum effect. Do not extend the local check beyond the minimum boundary result or produce persistence, post-fault, or concealment material.

### Respect source visibility

Deployment controls, proxy behavior, provider settings, browser headers, identity policy, broker ACLs, packaging, and topology are real controls. If they are required and absent from the repository, do not assume either presence or absence. Use `needs_validation` with the exact missing fact and a safe owner-observed or local plan.

### Separate priority from certainty

Only `confirmed` records receive severity. Likelihood and impact must reflect the demonstrated conditions and result; overall severity cannot exceed demonstrated impact. `needs_validation` means a specific source-grounded boundary hypothesis is blocked, not a low-confidence confirmed vulnerability, and it has no severity.

Calibrate overall severity with these anchors:

- **critical** — an unauthenticated actor gains code execution, full data-store access, or takeover of arbitrary accounts.
- **high** — an actor fully defeats an explicit security control with real consequences: authentication bypass, cross-tenant read or write, stored script execution affecting other users, authenticated code execution, or an unauthenticated remote stop of a shared service.
- **medium** — a real boundary violation with limited blast radius, uncommon preconditions, or consequences confined to a narrow resource set.
- **low** — disclosure of non-secret internals, or an effect requiring sustained effort for minimal gain.
- **informational** — a confirmed but minimal-impact observation, useful mainly as a prerequisite inside a larger finding.

The high/medium discriminator: does the demonstrated result fully defeat an explicit control for an action with real consequences, or only weaken it? If you cannot state the concrete damage, the severity is lower than it feels.

### Recommend the smallest effective source fix

For each confirmed finding, identify the invariant the code must enforce and the narrowest source change that enforces it at the last trusted decision point. Prefer specific repository-relative changes and regression tests over generic hardening advice. The audit describes fixes; it does not modify target source.

## References

Read only what the task needs, from `references/` (validators and `report-schema.json` are in `scripts/`).

| Read | When |
|---|---|
| `FULL-AUDIT.md` | Full audit mode: setup, write isolation, profiles (`quick`/`standard`/`deep`), budget, six-phase workflow |
| `RECONNAISSANCE.md`, `HUNTING.md`, `VALIDATION-AND-REPORTING.md` | The phases, when `FULL-AUDIT.md` sends you there |
| `ATTACK-CLASSES.md` | Core classes for any target: injection, access control, files/SSRF, crypto/secrets, business logic, feature abuse, chains, wildcard, obvious things |
| `SCANNERS.md` | Quick SAST, dependency and secret scans (leads only) |

Domain companions: pick the ones the target's surfaces cross.

| Companion | Target has |
|---|---|
| `WEB-PROTOCOL-AND-AUTH.md` | HTTP apps/APIs, proxies/CDNs, sessions, CSRF, JWT, OAuth/OIDC, SAML, MFA, passkeys, API keys, mTLS |
| `CLIENT-SIDE.md` | SPAs, extensions, webviews, service workers, postMessage, CORS, WebSockets, DOM rendering |
| `AI-AND-LLM.md` | RAG, memory, tool-calling agents, MCP servers/clients, prompt assembly, model-driven actions |
| `CLOUD-AND-DEPLOYMENT.md` | IAM, IaC, containers/Kubernetes, mesh, serverless/edge, ingress, runtime config |
| `SUPPLY-CHAIN-AND-RELEASE.md` | Dependency resolution, CI, release/signing, updates, plugins/extensions |
| `PROTOCOLS-RPC-AND-MESSAGING.md` | gRPC, GraphQL transport, custom protocols, queues/brokers, webhooks, streaming |
| `DATA-ISOLATION-AND-LIFECYCLE.md` | Multi-tenant stores, caches/search, export/backup, migration, deletion, restore |
| `RESOURCE-EXHAUSTION-AND-AVAILABILITY.md` | Untrusted work consuming shared CPU/memory/disk/queues/quotas/spend |
| `MEMORY-SAFETY-AND-BINARY.md` | C/C++/unsafe Rust, parsers/decoders, FFI, loaders, JITs, kernel, firmware |
| `DESKTOP-MOBILE-AND-LOCAL-IPC.md` | Native apps, deep links, webview bridges, privileged helpers, local daemons/IPC |

In guidance mode, apply each companion's `Core discipline` and `Validation rules` to the paths in question.

## Anti-patterns

1. Checklist deviations presented as vulnerabilities.
2. Defense-in-depth advice with no reachable boundary violation.
3. Live or shared-environment testing where bounded local evidence is insufficient.
4. Guessing provider, proxy, browser, identity, or deployment behavior not present in source.
5. Treating intended same-principal authority or self-impact as a cross-boundary result.
6. Reporting a parser or runtime effect stronger than the observed effect.
7. Emitting prose-only hunter results that cannot be deduplicated or verified.
8. Re-reporting carried same-source prior confirmed records or using them as exemplars that anchor the hunt.
9. Assigning severity to `needs_validation` records.
10. Writing the report before independent verification or letting prose and JSON disagree.
