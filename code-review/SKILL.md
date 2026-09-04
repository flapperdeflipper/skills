---
name: code-review
description: Review the changes since a fixed point (commit, branch, tag or merge-base) along two axes - Standards (does the code follow this repo's documented conventions?) and Spec (does the code do what the issue or ticket asked for?). Runs both as parallel sub-agents and reports them side by side. Use when reviewing a branch, a PR, work-in-progress changes, or when asked to "review since X".
---

# Code Review

Two-axis review of the diff between `HEAD` and a fixed point the user supplies.

- **Standards** - does the code conform to this repo's documented conventions?
- **Spec** - does the code faithfully implement the originating issue, ticket or spec?

Both axes run as **parallel sub-agents** so they do not pollute each other's context. This skill then aggregates.

Adapted from [mattpocock/skills](https://github.com/mattpocock/skills).

For a single file or a narrow domain, the dedicated commands are sharper: `/tf-review`, `/helm-review`, `/k8s-review`, `/docker-review`, `/sec-review`. Use this skill for whole-branch review.

## Process

### 1. Pin the fixed point

Whatever the user said is the fixed point: a commit SHA, branch name, tag, `master`, `HEAD~5`. If they did not specify one, ask.

Capture the diff command once: `git diff <fixed-point>...HEAD` (three-dot, so the comparison is against the merge-base). Note the commit list via `git log <fixed-point>..HEAD --oneline`.

Before going further, confirm the ref resolves (`git rev-parse <fixed-point>`) and the diff is non-empty. A bad ref or empty diff should fail here, not inside two parallel sub-agents.

### 2. Identify the spec source

Look for the originating spec, in this order:

1. Issue references in the commit messages (`#123`, `Closes #45`). Fetch with `gh issue view`.
2. A path the user passed as an argument.
3. A spec or plan file under `docs/`, `specs/` or the scratchpad matching the branch name.
4. If nothing is found, ask. If the user says there is no spec, the Spec sub-agent skips and reports "no spec available".

### 3. Identify the standards sources

Anything in the repo documenting how code should be written: `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `CODING_STANDARDS.md`, `.editorconfig`, lint configs. Global conventions in `~/.claude/CLAUDE.md` and the matching language skills (bash-scripting, python, terraform, helm, kubernetes, buildroot) count as documented standards too.

On top of what the repo documents, the Standards axis carries the baselines below. Two rules bind them:

- **The repo overrides.** A documented repo standard always wins. Where it endorses something a baseline would flag, suppress it.
- **Always a judgement call.** Each baseline item is a labelled heuristic ("possible Feature Envy"), never a hard violation. Skip anything tooling already enforces: shellcheck, shfmt, ruff, mypy, tflint, `terraform fmt`, `helm lint`.

**Code smell baseline** (Fowler, _Refactoring_ ch.3). Applies to Python, Go and any application code in the diff. Each reads *what it is* then *how to fix*:

- **Mysterious Name** - a function, variable or type whose name does not reveal what it does. Rename it; if no honest name comes, the design is murky.
- **Duplicated Code** - the same logic shape in more than one hunk or file. Extract it, call it from both.
- **Feature Envy** - a method reaching into another object's data more than its own. Move it onto the data it envies.
- **Data Clumps** - the same few fields or params keep travelling together. Bundle them into one type.
- **Primitive Obsession** - a string or primitive standing in for a domain concept. Give the concept its own small type.
- **Repeated Switches** - the same conditional cascade on the same type recurs. Replace with polymorphism or one shared map.
- **Shotgun Surgery** - one logical change forces scattered edits across many files. Gather what changes together.
- **Divergent Change** - one module edited for several unrelated reasons. Split it.
- **Speculative Generality** - abstraction, params or hooks added for needs the spec does not have. Delete it.
- **Message Chains** - long `a.b().c().d()` navigation the caller should not depend on. Hide the walk behind one method.
- **Middle Man** - a class or function that mostly just delegates. Cut it.
- **Refused Bequest** - a subclass that ignores most of what it inherits. Use composition.

**Infrastructure baseline.** Applies to Terraform, Helm, Kubernetes manifests, Dockerfiles, CI config and shell in the diff:

- **Hardcoded identity** - account IDs, project IDs, regions, cluster names or ARNs inline instead of variables, data sources or locals.
- **Credential in the diff** - any token, key or password, including a placeholder that looks real. Must be a reference to Vault, Secrets Manager, SOPS or ESO.
- **Silent insecure default** - public ingress, `0.0.0.0/0`, wildcard IAM actions or resources, disabled encryption, `privileged: true`, `latest` image tags, missing `runAsNonRoot`, unpinned action SHAs.
- **Unpinned dependency** - a provider, module, chart, base image or action referenced by floating tag or range.
- **Blast radius unstated** - a change that destroys or replaces state (forced replacement, resource rename without `moved`, PVC or StatefulSet edits) with no note of it.
- **Untested error path** - shell without `set -euo pipefail`, unquoted expansions, a masked exit code, or a pipeline whose failure is swallowed.
- **Implicit YAML** - unquoted values that YAML coerces (`on`, `no`, `1.10`, version strings), or a non-obvious key with no comment.

### 4. Spawn both sub-agents in parallel

Send a single message with two `Agent` tool calls. Use the `general-purpose` subagent for both.

**Standards sub-agent prompt** - include:

- The full diff command and commit list.
- The standards-source files found in step 3, **plus both baselines from step 3 pasted in full**. The sub-agent has no other access to them.
- The brief: "Report, per file and hunk where relevant, (a) every place the diff violates a documented standard, citing the standard by file and rule; and (b) any baseline item you spot, naming it and quoting the hunk. Distinguish hard violations from judgement calls: documented-standard breaches and the credential/insecure-default items can be hard, the rest are judgement calls, and a documented repo standard overrides the baseline. Skip anything tooling enforces. Under 400 words."

**Spec sub-agent prompt** - include:

- The diff command and commit list.
- The path or fetched contents of the spec.
- The brief: "Report: (a) requirements the spec asked for that are missing or partial; (b) behaviour in the diff that was not asked for (scope creep); (c) requirements that look implemented but where the implementation looks wrong. Quote the spec line for each finding. Under 400 words."

If the spec is missing, skip the Spec sub-agent and say so in the final report.

### 5. Aggregate

Present the two reports under `## Standards` and `## Spec` headings, verbatim or lightly cleaned. Do **not** merge or rerank findings: the two axes are deliberately separate.

End with one line: total findings per axis, and the worst issue _within each axis_. Do not pick a single winner across axes, that is the reranking this separation exists to prevent.

## Why two axes

A change can pass one axis and fail the other:

- Code that follows every standard but implements the wrong thing: **Standards pass, Spec fail.**
- Code that does exactly what the issue asked but breaks the project's conventions: **Spec pass, Standards fail.**

Reporting them separately stops one axis from masking the other.
