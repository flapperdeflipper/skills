<!-- source: flapperdeflipper, MIT -->
## What it is (2026-09-29)

The automation server on hd (hd.pl4.dev): one Compose stack from
`flapperdeflipper/automation-suite`, deployed by merging to `main` (once CI
passed).

| Piece | Job | Agents reach it via |
|---|---|---|
| Dagu (patched) | durable jobs: deploys, builds, backups, scripts on hosts; history, retries | MCP `dagu`, https://work.pl4.dev, `dagu` CLI context `hd` |
| webhook | deploy hook: the last CI job of a repo (reusable `deploy.yml`, GitHub OIDC token) enqueues its deploy DAG and waits for it | none (config in the repo) |
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
  every DAG is event-triggered (CI deploy job, HA automation, MCP) or manual.
- ha, hb and hc keep a read-only checkout at `/srv/automation-suite`
  (`sync-suite-checkout`, when CI passed on `main`).
- Step processes don't get the worker container's environment. Read
  settings from files (`/srv/automation-suite/.env` →
  `/data/automation-suite/...`).
- Repo deploys on merge: a DAG taking `REF`, a line in
  `config/webhook/routes` (`<owner/repo> <branch> <dag>`), and a last CI job
  `uses: flapperdeflipper/automation-suite/.github/workflows/deploy.yml@main`
  (`if: github.event_name == 'push'`, `permissions: id-token: write`). It
  enqueues the routed DAGs with the pushed commit and waits for them; one
  deploy per repo and branch at a time. Deploys never go back to an older
  commit unless `FORCE=1` (a rollback). Details: automation-suite
  `docs/operations.md`.
- Dagu itself: `dagu-update` (build + smoke test + PR), merge, then
  `dagu-upgrade-workers`.

## Gotchas

- **State:** everything lives in `/data/automation-suite` on hd. Secrets are
  in `env/*.env` there, never in git.
- **Merging `automation-suite` deploys hd** as the last job of CI, and that job only ends once the hd worker was replaced. The stack's worker restarts
  last, from a helper container, so the deploy step still reports its result.
- **Firewall:** published ports on hd pass the DOCKER-USER guard, which only
  lets in hb/ha (VLAN 60) and the workers (:50055). New sources:
  `bin/suite guard hd.pl4.dev allow <iface> <ip> [port]`.
