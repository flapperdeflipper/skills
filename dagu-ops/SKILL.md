---
name: dagu-ops
description: "Operating a running Dagu instance through its Web UI (dashboard, execution monitoring, history, logs) and REST API (start/stop/retry, status and history queries, log retrieval, CI/CD integration). Use for managing or monitoring Dagu; DAG YAML authoring belongs to the dagu skill."
license: MIT
---

# Dagu ops

Router. Read only the guide the task needs: `<guide>/GUIDE.md` in this skill's
directory.

| Guide | Read when |
|---|---|
| `rest-api` | Programmatic workflow management over HTTP: start/stop/retry/restart, status and history queries, log retrieval, DAG CRUD, search, CI/CD and webhook integration |
| `webui` | Browser operations: dashboard, manual start/stop, real-time execution monitoring, history and retries, DAG visualization, troubleshooting stuck workflows |

Adapted from [vinnie357/claude-skills](https://github.com/vinnie357/claude-skills/tree/main/plugins/tools/dagu/skills) (MIT, Vinnie Mazza; see LICENSE), which packages
docs.dagu.cloud content accessed 2025-11-15. The upstream `workflows` facet
was skipped — the vendored `dagu` skill tracks the installed CLI version and
is the authority for DAG YAML syntax. These guides may lag the running server
(upstream was last checked against v2.11.1): verify field names and endpoints
against the live instance when exactness matters.
