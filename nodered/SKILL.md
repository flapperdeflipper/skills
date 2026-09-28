---
name: nodered
description: "This home's Node-RED (automation-suite on hd, https://flows.pl4.dev): build, change and debug flows through the nodered MCP tools, wire MQTT (automation/#), Home Assistant, GitHub events and Dagu jobs, and keep flows in git. Use for event-driven glue (MQTT, HA state, HTTP, GitHub events) or when choosing between a Node-RED flow and a Dagu DAG."
---

# Node-RED in this house

State as of 2026-09-28. Node-RED is the event side of the **automation-suite**
stack on hd; Dagu (skill `dagu`, `references/house.md`) is the job side.

## Flow or DAG?

| Want | Use |
|---|---|
| React within seconds to an MQTT message, HA state change, GitHub event or HTTP call, and do one or two things | **Node-RED flow** |
| A job: deploy, build, backup, script on a host, steps with retries, history, approval | **Dagu DAG** (PR adding `workflows/<name>.yaml` in automation-suite) |
| An event should start a job | Flow → HTTP request to Dagu's enqueue API (below) |

## Where it runs

| What | Where |
|---|---|
| Container | `node-red` in the stack on hd (`/srv/automation-suite`), data in `/data/automation-suite/node-red` |
| Editor | https://flows.pl4.dev: vouch first, then Node-RED's own login (user `admin`, password `NODE_RED_ADMIN_PASSWORD` in `/data/automation-suite/env/node-red.env` on hd) |
| Internal URL | `http://10.60.0.10:1880` (LAN side), `http://node-red:1880` (from other stack containers) |
| Admin API | same URL, `Authorization: Bearer $NODE_RED_API_TOKEN` (from `node-red.env`); 401 without it |
| MCP | LiteLLM gateway server `nodered` → nodered-mcp (`http://10.60.0.10:3000/mcp`); allowed on key `toolset-hass` and on unrestricted keys |
| Palette | core nodes + `node-red-contrib-home-assistant-websocket@0.80.3`, pinned in `images/node-red/Dockerfile` |

## Working through the MCP

1. `nodered_info` first, then `list_flows` / `get_flow` / `search_nodes`. Extend an existing flow rather than duplicating it.
2. Build with `create_flow`. Change with `update_flow`, running `dry_run: true` first: it shows the added, removed and changed nodes. Both deploy only that flow.
   - Every node needs a unique 16-hex `id`; `wires` reference those ids; omit `z`.
   - Config nodes the flow needs (mqtt-broker, HA server, ...) go in `configs`.
   - Give every flow an `info`: what it's for and who asked.
3. Test: `inject` an inject node, then `read_debug` (filter by flow id or debug node id). `get_context` reads global, flow or node context.
4. Record it: `export_flows` with a short reason. That enqueues the Dagu DAG `nodered-export`, which commits `nodered/flows.json` to automation-suite; it also runs every 15 min.
5. Mistakes: every update and delete is backed up first (`list_backups`, `restore_backup`); `delete_flow` needs `confirm: true`.
6. Missing node type? `list_node_types`. New modules are a PR in automation-suite (Dockerfile), never an install in the editor.

## Rules

- Ask the user before any flow that actuates devices, arms or disarms anything, or publishes to command topics. Reading and notifying are fine.
- Secrets go in config-node credentials (encrypted with `NODE_RED_CREDENTIAL_SECRET`, never exported to git). Never put them in function nodes, `info`, names or flow JSON.
- MQTT: the suite owns `automation/...`. Dagu job results go to `automation/dagu/status/<dag>`.
- `http in` endpoints under `/events/` require `Authorization: Bearer $NODE_RED_EVENTS_TOKEN` (enforced in `settings.js`). Keep anything reachable from outside under `/events/`.

## Integrations

**MQTT** (Mosquitto add-on on ha):
- Broker `10.20.0.3:1883`, user `nodered`, ACL read/write on `automation/#` only.
- The broker's ACL check is `rw >= level`, so a topic you can subscribe to is also writable; "read everything, write some" isn't possible.
- Values are in `node-red.env` on hd as `MQTT_NODERED_HOST`, `_PORT`, `_USER` and `_PASSWORD`; the container has them in its environment.
- In the `mqtt-broker` config node, server, port and user can use Node-RED's `${MQTT_NODERED_HOST}`-style env substitution. Enter the password as a credential.

**Home Assistant**:
- Use a `server` config node from `node-red-contrib-home-assistant-websocket`, base URL `http://10.60.0.3:8123`.
- Access token: a long-lived token of a dedicated HA user `nodered` (not admin unless needed). Create it in HA and enter it as the credential.
- HA events and state come over this websocket, not MQTT.

**GitHub events**:
- The webhook service (`https://hooks.pl4.dev/hooks/github`, HMAC-checked) forwards **every** org event to `POST /events/github`.
- The body is `{"source":"github","event","delivery","repo","ref","sha","action","sender"}`.
- The flow tab "github events" (`http in` → `202` response + debug) receives them. Add logic after the `http in`; keep the `202` response.
- Pushes on routed repos also start their Dagu deploy DAG directly. That goes through the webhook service, not Node-RED.

**Starting a Dagu job from a flow**:
- `http request` node, POST `http://dagu:8080/api/v1/dags/<dag>/enqueue`.
- Headers `Authorization: Bearer <key>` and `Content-Type: application/json`; body `{"params": "KEY=value"}`.
- Use a Dagu API key with role `operator` (Dagu UI → API keys, e.g. named `node-red`), stored as a credential, never in the flow JSON.

## Flows and git

- Live flows are the source; git keeps every version (`nodered/flows.json`, exported by `nodered-export`).
- **Restore** an old version: take `nodered/flows.json` from git history and deploy it with `update_flow` per flow, via the editor (Import), or the admin API (`POST /flows` with `Node-RED-Deployment-Type: full`, which replaces everything).
- **Empty live exports:** a fresh or wiped Node-RED exports `[]`. That once replaced the real flows in git right after the hd cut-over (restored, `f47d7db`). With automation-suite PR #2 the export refuses to commit `[]` over non-empty flows (`ALLOW_EMPTY=1` overrides), and bootstrap seeds a fresh instance from git.

## Over SSH (admins)

```
ssh 10.20.0.10
cd /srv/automation-suite
sudo docker compose logs -f node-red nodered-mcp
sudo docker compose restart node-red
t=$(sudo sed -n 's/^NODE_RED_API_TOKEN=//p' /data/automation-suite/env/node-red.env)
curl -fsS -H "Authorization: Bearer $t" http://10.60.0.10:1880/flows | jq length
```

- **Env changes** (`env/node-red.env`) need the container recreated: `sudo docker compose up -d node-red`. A restart alone keeps the old environment.
- **Architecture and runbooks** live in the automation-suite repo: `README.md`, `AGENTS.md` and `docs/`.
