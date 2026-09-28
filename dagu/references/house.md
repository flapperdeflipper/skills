# Dagu in this house

Local knowledge, maintained in this repo (not upstream). Where it differs from
the generic references, this file wins. State as of 2026-09-28.

## Topology

| What | Where |
|---|---|
| Server (UI, API, scheduler, coordinator) | hd, container `dagu` of the **automation-suite** Compose stack |
| UI | https://work.pl4.dev (Gitea SSO "Sign in with git.pl4.dev"; local `admin` as fallback) |
| API base URL | `https://work.pl4.dev/api/v1` (inside the stack: `http://dagu:8080/api/v1`) |
| MCP | `https://work.pl4.dev/mcp`, used through the LiteLLM gateway entry `dagu` |
| Coordinator (gRPC, mTLS) | `hd.pl4.dev:50055` |
| Workers | `hd` (container `worker` in the stack), `ha` (10.20.0.3), `hb` (10.20.0.2), `hc` (10.20.0.4): native `dagu worker` systemd services as user `dagu` |
| Version | 2.17.2 everywhere. The server is a patched build (license-gated features on); workers and the CLI are upstream |
| Stack checkout / state on hd | `/srv/automation-suite` / `/data/automation-suite` (env files in `env/`, Dagu data in `dagu/`, CA key in `dagu/tls/ca/`) |

What a job can touch depends on where it runs:

- `hd`: the worker container has the Docker socket (it deploys the stack), so a job there can do anything on hd.
- `ha`, `hc`: user `dagu` in the `docker` group (so effectively root there too).
- `hb`: user `dagu`, no sudo, no docker. Root-needing steps need a per-job sudo rule on hb first.

## Where workflows live

- DAGs are files in `workflows/` of **flapperdeflipper/automation-suite**. Git-sync pulls `main` into Dagu every 120 s.
- Change a DAG by PR, never in the Dagu UI: the next sync would diverge from or overwrite UI edits.
- A merge to `main` also redeploys the stack itself (`deploy-automation-suite`); say so in the PR if it restarts services.
- Merge → deploy for other repos: GitHub org webhook → `https://hooks.pl4.dev/hooks/github` (HMAC-checked) → `dispatch-github` enqueues the DAG routed in `config/webhook/routes` (`<owner/repo> <branch> <dag>`) with param `REF=<sha>`. The deploy DAGs keep a slow schedule only as a fallback for a lost delivery: `deploy-automation-suite` every 30 min, the music-service deploy hourly. `deploy-appdaemon-on-merge` still polls every 5 min.
- New deploy for a repo: add `workflows/<name>.yaml` and a routes line, in one PR.

## Writing a workflow here

- Pin the host: `worker_selector: {host: hd|ha|hb|hc}`. The stack leaves `default_execution_mode` at its default, so a DAG without a selector runs locally inside the server container `dagu`, not on a worker. Always pin one.
- Deploys: `max_active_runs: 1`, set `timeout_sec` and `hist_retention_days`, make scripts idempotent (fetch → compare → apply). Copy the pattern from `deploy-automation-suite.yaml` or `deploy-docker-compose-music-service.yaml`.
- Secrets never go in a DAG file. Use Dagu's secret store, or env files under `/data/automation-suite/env/` read by a step on `hd`.
- Private repos on a worker: `deploy-appdaemon-on-merge.yaml` shows the pattern (deploy key under `/var/lib/dagu/.ssh/keys/`, `GIT_SSH_COMMAND`).
- Report results for Node-RED flows on MQTT `automation/dagu/status/<dag>` (see the `nodered` skill).

## Validate and try locally (any agent with the CLI)

The agent add-ons ship `dagu` 2.17.2 (agent-base). `validate` and `dry` are local-only commands; pass `--context local` so they never go to the server:

```
dagu validate workflows/my-job.yaml --context local   # schema/field errors, exit != 0 on error
dagu dry workflows/my-job.yaml --context local        # walks the steps without running them
dagu start workflows/my-job.yaml --context local      # really runs it, but inside YOUR container
dagu schema dag                                       # every field and its shape
```

A local `start` runs in the agent's container, not on the house hosts, so it's only for trying logic. Anything touching hd/ha/hb/hc goes through a PR and the server.

## Run and inspect on the server

### CLI with a remote context

```
dagu context add hd --server https://work.pl4.dev/api/v1 --api-key <key>   # API base URL, not the site
dagu context use hd
dagu context test hd                      # "reachable"
dagu history deploy-automation-suite      # recent runs
dagu status <dag>                         # latest run
dagu enqueue <dag> -- KEY=value           # queue a run with params
dagu start <dag>                          # run now
dagu stop <dag> | dagu retry <dag> --run-id <id> | dagu restart <dag> | dagu dequeue <queue>
```

- Only `start`, `enqueue`, `status`, `history`, `stop`, `retry`, `restart` and `dequeue` follow the remote context. Everything else runs locally.
- `--server https://work.pl4.dev` without `/api/v1` fails every command with `invalid character '<'`, because it gets an HTML page back.
- The OpenCode add-on on ha already has context `hd`, using the operator key `agents-cli`. The same key is also:
  - in the add-on's env var `DAGU_API_TOKEN`, for scripts and `curl`;
  - in ha's `secrets.yaml` as `dagu_hass_api_key`.

  Its CLI state lives in `/data/dagu`, and the startup hook `/homeassistant/opencode/startup.d/10-dagu-state.sh` links it back into `/root` after updates.

### MCP (LiteLLM gateway)

- Server `dagu`, tools `dagu_read` (DAGs, specs, runs, logs, wiki) and `dagu_execute` (run, enqueue, stop, retry).
- The gateway's key is `operator`, so `dagu_change` (editing DAGs) is refused on purpose: change DAGs by PR.
- The per-toolset virtual keys (`toolset-hass/home/remote`) don't include `dagu`; only unrestricted keys reach it.

### REST

```
curl -fsS -X POST https://work.pl4.dev/api/v1/dags/<dag>/enqueue \
  -H "Authorization: Bearer <key>" -H "Content-Type: application/json" \
  -d '{"params": "KEY=value"}'
curl -fsS https://work.pl4.dev/api/v1/dag-runs?name=<dag>\&limit=5 -H "Authorization: Bearer <key>"
```

API keys: Dagu UI → API keys, role `operator` unless the consumer must edit DAGs. Existing keys (all `operator`): `webhook`, `nodered-mcp`, `agents-cli` (REST), `litellm` (MCP).

### Over SSH (admins, from the laptop)

```
ssh 10.20.0.10
cd /srv/automation-suite
sudo docker compose ps                                     # stack health
sudo docker compose logs -f dagu worker                    # server + hd worker
sudo docker compose exec -T dagu dagu history <dag> --config /etc/dagu/config.yaml
sudo docker compose exec -T dagu dagu enqueue <dag> --config /etc/dagu/config.yaml
```

- Inside the `dagu` container every CLI command needs `--config /etc/dagu/config.yaml` (`DAGU_HOME=/var/lib/dagu`).
- Native workers: `ssh 10.20.0.3 'sudo journalctl -u dagu -f'` (same for hb/hc). Their config and certs are in `/etc/dagu`.
- From a laptop checkout of automation-suite: `bin/suite status` for stack, guard and workers; `bin/suite node add <name> <ssh-target>` adds a worker; `bin/suite guard <target> list|allow|deny` for the DOCKER-USER guard.

## Operations

- **Upgrade Dagu:** the `dagu-update` DAG builds and smoke-tests a patched release and opens the version-bump PR. After the merge, `dagu-upgrade-workers` brings ha/hb/hc to the same version. Server and workers must match.
- **Network:** published ports are guarded by DOCKER-USER (`suite-guard`). A ufw INPUT rule `172.18.0.0/16 → 10.20.0.10:50055` lets the stack's own containers reach the coordinator; don't delete it.
- **Backups:** `/data/automation-suite` holds everything that can't be rebuilt: users, API keys, history and the worker CA key.
- **Docs:** full setup and cut-over history in the automation-suite repo (`README.md`, `AGENTS.md`, `docs/`).
