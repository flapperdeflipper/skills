<!-- source: flapperdeflipper, MIT -->
## What it is (2026-09-29)

The automation server on hd (hd.pl4.dev): one Compose stack from
`flapperdeflipper/automation-suite`, deployed by merging to `main` (once CI
passed).

| Piece | Job | Agents reach it via |
|---|---|---|
| Dagu (patched) | durable jobs: deploys, builds, backups, scripts on hosts; history, retries | MCP `dagu`, https://work.pl4.dev, `dagu` CLI context `hd` |
| webhook | GitHub org webhook ingress: green CI on a deploy branch (`workflow_run`) → Dagu deploy DAG | none (config in the repo) |
| workers | `hd` (in the stack), `ha`, `hb`, `hc` (native systemd) | `worker_selector: {host: <name>}` in a DAG |

Repo docs are the source of truth: `README.md`, `AGENTS.md` (agent rules),
`docs/operations.md`.

## Dagu or a Home Assistant automation

Node-RED was removed on 2026-09-29 (it only logged GitHub events).
- Seconds, one or two calls, reacting to an event → **HA automation**.
- Steps, retries, history, approvals, SSH, deploys → **Dagu DAG**.
- Event that should start a job → an HA automation with a `rest_command`
  to Dagu's enqueue API (`POST https://work.pl4.dev/api/v1/dags/<dag>/enqueue`,
  bearer API key).

## Dagu

- DAGs are files in `automation-suite/workflows/`, changed by PR; git-sync
  loads them within 2 min. Don't edit DAGs in the UI.
- Pin to a host with `worker_selector`; use `max_active_runs: 1` for
  deploys; write idempotent steps (fetch → compare → apply).
- Logic lives in `workflows/scripts/<dag>/<step>.sh`; the step is one line
  and lists the scripts in `dependencies` (CI checks it). No `schedule:`:
  every DAG is event-triggered (webhook route, HA automation, MCP) or manual.
- ha, hb and hc keep a read-only checkout at `/srv/automation-suite`
  (`sync-suite-checkout`, when CI passed on `main`).
- Step processes don't get the worker container's environment. Read
  settings from files (`/srv/automation-suite/.env` →
  `/data/automation-suite/...`).
- Repo deploys on merge: a DAG taking `REF`, plus a line in
  `config/webhook/routes` (`<owner/repo> <branch> <after> <dag>`). `<after>`
  is the repo's CI workflow file (`ci.yml`, run when it passed for a push to
  the branch) or `push` for a repo without CI. Deploys never go back to an
  older commit unless `FORCE=1` (a rollback).
- Dagu itself: `dagu-update` (build + smoke test + PR), merge, then
  `dagu-upgrade-workers`.

## Gotchas

- **State:** everything lives in `/data/automation-suite` on hd. Secrets are
  in `env/*.env` there, never in git.
- **Merging `automation-suite` deploys hd** once `ci.yml` passed. The stack's worker restarts
  last, from a helper container, so the deploy step still reports its result.
- **Firewall:** published ports on hd pass the DOCKER-USER guard, which only
  lets in hb/ha (VLAN 60) and the workers (:50055). New sources:
  `bin/suite guard hd.pl4.dev allow <iface> <ip> [port]`.
