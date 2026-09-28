<!-- source: flapperdeflipper, MIT -->
## What it is (2026-09-28)

The automation server on hd (hd.pl4.dev): one Compose stack from
`flapperdeflipper/automation-suite`, deployed by merging to `main`.

| Piece | Job | Agents reach it via |
|---|---|---|
| Dagu (patched) | durable jobs: deploys, builds, backups, scripts on hosts; history, retries | MCP `dagu`, https://work.pl4.dev, `dagu` CLI context `hd` |
| Node-RED 5 | events + light glue: MQTT, Home Assistant, GitHub events, HTTP | MCP `nodered`, https://flows.pl4.dev |
| webhook | GitHub org webhook ingress: push → Dagu deploy DAG, all events → Node-RED `/events/github` | none (config in the repo) |
| workers | `hd` (in the stack), `ha`, `hb`, `hc` (native systemd) | `worker_selector: {host: <name>}` in a DAG |

Repo docs are the source of truth: `README.md`, `AGENTS.md` (agent rules),
`docs/operations.md`.

## Dagu or Node-RED

- Seconds, one or two calls, reacting to an event → **Node-RED flow**.
- Steps, retries, history, approvals, SSH, deploys → **Dagu DAG**.
- Event that should start a job → Node-RED flow calls Dagu's enqueue API
  (`POST http://dagu:8080/api/v1/dags/<dag>/enqueue`, bearer API key).

## Node-RED via the `nodered` MCP

Tools: `nodered_info`, `list_flows`, `get_flow`, `search_nodes`,
`create_flow`, `update_flow` (`dry_run` shows a node diff), `delete_flow`
(`confirm: true`), `list_backups`, `restore_backup`, `inject`, `read_debug`
(live debug-node output), `get_context`, `list_node_types`, `export_flows`.

Workflow:
1. Inspect first: `list_flows` / `get_flow`. Extend a flow rather than
   duplicate it.
2. Build: `create_flow` or `update_flow`. Nodes need unique 16-hex ids;
   wires reference them; omit `z`. Put the purpose in the flow's `info`.
3. Test: `inject`, then `read_debug` for that flow.
4. Record: every deploy is exported to git automatically (~20 s after it
   settles; `nodered-export` commits `nodered/flows.json`). `export_flows`
   with a reason gives the commit a meaningful message.
5. Undo: every update/delete is backed up; use `list_backups`, then
   `restore_backup`.

Rules:
- Confirm with the user before flows that actuate devices, arm/disarm, or
  publish to command topics.
- MQTT: Node-RED's broker user (`nodered`) owns `automation/#` only. Dagu job
  results go to `automation/dagu/status/<dag>`. HA events come through the
  HA websocket nodes.
- The palette is pinned in the image. New node modules are a PR to
  `images/node-red/Dockerfile`, never an editor install.
- Secrets only in config-node credentials (encrypted, never exported).

## Dagu

- DAGs are files in `automation-suite/workflows/`, changed by PR; git-sync
  loads them within 2 min. Don't edit DAGs in the UI.
- Pin to a host with `worker_selector`; use `max_active_runs: 1` for
  deploys; write idempotent steps (fetch → compare → apply).
- Logic lives in `workflows/scripts/<dag>/<step>.sh`; the step is one line
  and lists the scripts in `dependencies` (CI checks it). No `schedule:`:
  every DAG is event-triggered (webhook route, Node-RED, MCP) or manual.
- ha, hb and hc keep a read-only checkout at `/srv/automation-suite`
  (`sync-suite-checkout`, on every push to `main`).
- Step processes don't get the worker container's environment. Read
  settings from files (`/srv/automation-suite/.env` →
  `/data/automation-suite/...`).
- Repo deploys on merge: a DAG taking `REF`, plus a line in
  `config/webhook/routes` (`<owner/repo> <branch> <dag>`).
- Dagu itself: `dagu-update` (build + smoke test + PR), merge, then
  `dagu-upgrade-workers`.

## Gotchas

- **State:** everything lives in `/data/automation-suite` on hd. Secrets are
  in `env/*.env` there, never in git.
- **Merging `automation-suite` deploys hd.** The stack's worker restarts
  last, from a helper container, so the deploy step still reports its result.
- **Firewall:** published ports on hd pass the DOCKER-USER guard, which only
  lets in hb/ha (VLAN 60) and the workers (:50055). New sources:
  `bin/suite guard hd.pl4.dev allow <iface> <ip> [port]`.
