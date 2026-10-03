<!-- source: flapperdeflipper, MIT -->
## One endpoint, three toolsets (2026-09-25)

Every self-hosted MCP server is registered **on the LiteLLM proxy** and
clients add a single MCP entry: `https://llm.pl4.dev/mcp` (internal
`http://ha.pl4.dev:4000/mcp`) with a Bearer toolset key. `/v1` (models) and
`/mcp` (tools) bypass the nginx/vouch OAuth layer, which only guards the
human UI — agents never see OAuth.

Registered on the gateway (config.yaml `mcp_servers:`, upstream auth
server-side): homeassistant (via mcp-hub → ha_opencode:8927, needs mcp-hub
≥ 1.1.1), ha_native, victoriametrics, chrome_devtools (all via mcp-hub :8930),
searxng (:8086), context7, github, dagu (external, tokens server-side),
memory and docstore (via mcp-hub :8930 — see Memory section). Server names
must not contain `-` (LiteLLM rejects them).

Toolsets have two layers, and since 2026-09-27 they deliberately diverge
(`dagu` is scoped to hass only; `docstore` joined all three later that day):

1. Virtual keys: `object_permission.mcp_servers` allowlists (values in
   secrets.yaml), nominally effective on `/mcp` — but they are NOT the
   gate: `docstore` and `dagu` are served without being on any list.
   Layer 2 is the gate that actually controls `/mcp`. `/key/update`
   with `object_permission.mcp_servers` did apply a rename on
   2026-10-01 (playwright → chrome_devtools on all three keys; it also
   dropped the unregistered `nodered` from hass), after failing to add
   `dagu` on 2026-09-27 — keep the lists tidy, but verify `/mcp`, not
   the list.
2. Native toolset objects: DB rows with hard-coded per-tool lists served
   at `/toolset/<name>/mcp` — this is LiteLLM-native routing, NOT nginx.
   The paths do NOT follow the key allowlists (a master key on
   `/toolset/home/mcp` still gets only the toolset's listed tools) and
   they validate key↔toolset. Sync them via `GET/PUT /v1/mcp/toolset`
   (`{toolset_id, tools: [{server_id, tool_name}]}`) — after adding an
   MCP server, append its tools to every toolset that should see them
   (copying hass's list into home/remote only when the server is for
   all three).

| Toolset | Secret | Sees |
|---|---|---|
| hass | `litellm_hass_key` | 10 servers (200 tools) — the 9 below + `dagu` |
| home | `litellm_home_key` | 9 servers (197 tools) + all models |
| remote | `litellm_remote_key` | 9 servers (197 tools) + all models |

The 9 shared servers: homeassistant, ha_native, victoriametrics,
chrome_devtools, searxng, context7, memory, github, docstore. Counts are what
the keys actually serve on `/mcp` (measured 2026-10-01 via initialize +
tools/list per key); the toolset rows hold 7 stale entries more (207/204,
constant gap, harmless).

opencode on the HA box wires this via ha_opencode ≥ 3.1.0
(`mcp_litellm_url`, key env `LITELLM_HASS_KEY`); distributed configs live in
`/share/syncthing/media/opencode/` (their MCP entry points at `/mcp` since
2026-09-26; the `/toolset/<name>/mcp` paths also work and carry each
toolset's own list — they diverged 2026-09-27: only hass serves dagu). The
mcp-hub (:8930) and :8927 endpoints remain — as upstreams for the gateway,
not for clients.

## Registered servers and aliases

| Server | Provides |
|--------|----------|
| `homeassistant` | full ha-mcp-server (73 tools) via mcp-hub → ha_opencode:8927 |
| `ha_native` | curated Assist/entity-control tools from Core's own MCP endpoint (via mcp-hub) |
| `chrome_devtools` | shared headless Chromium via chrome-devtools-mcp (mcp-hub ≥ 2.0.0 `/mcp/chrome-devtools`; browser runs inside the hub container, no CDP port). Page-scoped tools take a `pageId`; `new_page` takes `isolatedContext` for separate cookies/storage. Replaced `playwright` on 2026-10-01 |
| `victoriametrics` | PromQL tools against Victoria Metrics (via mcp-hub) |
| `searxng` | web + code search (direct, :8086) |
| `context7` | up-to-date library documentation (external, token server-side) |
| `memory` | LiteLLM `/v1/memory` store via mcp-hub: `memory_search/tags/get/set/list/delete` (search-first) |
| `github` | GitHub remote MCP — repos, issues, PRs, code search (external, `GITHUB_MCP_TOKEN` server-side) |
| `docstore` | agent docstore `doc_*` + `task_claim`/`task_complete` (couchdb add-on) via mcp-hub — in all three toolsets since 2026-09-27 |
| `dagu` | Dagu orchestrator at work.pl4.dev — `dagu_read`/`dagu_change`/`dagu_execute` (external, `DAGU_MCP_API_KEY` server-side; hass toolset only) |

Tool names arrive namespaced per server (`litellm_homeassistant-*`,
`litellm_searxng-*`, …).

## Lazy loading (tool-search keys)

Keys created with `mcp_tool_search_enabled: true` expose only three virtual
tools regardless of catalog size: `mcp_tool_search(query)` → ranked matches →
`mcp_tool_call(tool_name, arguments)`. Use these for agents where context
window matters; use normal keys for agents that benefit from the full catalog.

## Discovery

- `registry_list` (litellm_mcp tool) — what the memory package offers
- `GET /mcp-rest/tools/list` — full tool catalog (needs key)
- `GET /public/skill_hub` — published agent skills
- `/ui/model_hub_table` — public model/tool hub page

## Debugging and adding servers

REST equivalent of a tool call (no MCP client needed):

    curl -X POST http://ha.pl4.dev:4000/mcp-rest/tools/call \
      -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
      -d '{"server_id":"litellm_mcp","name":"memory_list","arguments":{}}'

Servers are registered in `/homeassistant/litellm/config.yaml` under
`mcp_servers:`. A NEW server entry needs an add-on restart — the config
watcher does not register never-seen servers (dagu, 2026-09-27: a touch
left the catalog unchanged; the restart registered it). Gotcha: stdio children get a **scrubbed environment** —
pass required variables via the per-server `env:` map using
`os.environ/<NAME>` references. Custom tool code lives in the
`litellm_mcp` package (`mcp_servers/litellm_mcp/` in the litellm add-on):
a module + one REGISTRY line adds tools.

## Thinking variants (deliberate, 2026-09-19)

`litellm/config.yaml` exposes glm-5.3, glm-5.2 and glm-5.3-flash each as
`-think`/`-nothink` deployments, plus `glm-5.3-flash-small` (thinking off,
512-token default output cap, caller-overridable). The bare `glm-5.3` entry
keeps **forced reasoning_effort: high** on purpose. No variants for deepseek
(reasons upstream regardless) or the zen free models (free tier refuses
non-OpenCode clients).

Why: zai's coding-plan endpoint honors `thinking:{"type":"disabled"}`, but
LiteLLM's `zai/` transform combined with a configured `reasoning_effort`
silently drops a caller's disable request — nothink variants MUST route
through the `openai/` transform with `extra_body.thinking`. The opencode
`small_model` (zai-coding-plan/glm-5.3-flash) calls the coding endpoint
direct and bypasses the gateway.

## zai-coding-plan models in opencode

Source of truth: drop-in `/addon_configs/4e94d283_ha_opencode/03-zai-models.json`.
opencode UNIONS configured models with the bundled models.dev catalog, so a
config-only list never removes catalog models — use the provider `whitelist`
(the 2026-09-23 set: glm-5, 5-turbo, 5.1, 5.2, 5.3, 5.3-flash).
`"model": false` is NOT supported by opencode 1.18.x and breaks the whole
provider entry. api.models.dev is DNS-blocked in the container, so the bundled
catalog never refreshes. Live upstream list: GET
`https://api.z.ai/api/coding/paas/v4/models` (hasecret `z_ai_api_token`);
vision/free models are served but not advertised — probe to discover.
glm-5.3-flashx is plan-blocked (error 1311). After editing drop-ins:
`rm /data/.config/opencode/config.json && bash
/usr/local/lib/opencode/merge-config-dropins /data/.config/opencode/config.json /config`
(deep-merge cannot delete keys). New sessions pick it up; the 4096 server
needs an add-on restart.

## Cache bootstrap lesson (LiteLLM v1.100.0, 2026-09-18)

The `litellm_settings.cache_params` block in `/homeassistant/litellm/config.yaml`
is REQUIRED bootstrap config even though the Admin UI/DB cache row overrides
it later — `load_config()` builds the startup cache from YAML before the DB
row applies. Hardened same day: literal `REDIS_HOST`/`REDIS_PORT` env vars on
the add-on give the env fallback a working connection, so a missing/broken
block boots with a degraded cache (db 0, no namespace) until the DB row
applies. Keep the YAML params in sync with the Admin UI row.

Related: MCP servers are also DB-registered (`GET/DELETE /v1/mcp/server/{name}`);
deleting one whose URL is dead can wedge the proxy during teardown — expect a
restart; delete-by-NAME works while the hash server_id returns "not found".
Watchdog + healthcheck are enabled; wedge self-heal is slow (~90s start +
3×30s retries). Uptime Kuma (port 3001) monitors the gateway at
`https://llm.pl4.dev/health/liveliness` (monitor id 26); its API key
(`opencode_uptime_kuma_token`) is metrics-only — Kuma 2.5.5 socket.io login
needs username+password, no REST for monitors.

## Guardrails: deliberately removed

All four LiteLLM guardrails (hide-secrets, mcp-security, pii-mask,
tool-policy) were removed from `/homeassistant/litellm/config.yaml` on
2026-09-18 at the user's request. Do not re-add them or "fix" their absence
without asking. The DB tool-policy table (152 tools) still exists but is
inert without the guardrail.

## Memory: search-first (2026-09-26; supersedes the 2026-09-23 retirement)

The `/v1/memory` store is served to agents through mcp-hub's `memory`
server (mcp-hub ≥ 1.2.0; the `memory_api_key` option holds a
`!secret litellm_memory_key` value). Registered on the gateway as `memory`
in `litellm/config.yaml` — after editing that block, restart the proxy
to load it: an mtime `touch` triggers nothing (no inotify path reaches
the proxy through the docker/union-fs boundary; verified 2026-09-26). Do
NOT register it via POST `/v1/mcp/server`: the
API row and the config-synced row collide (symptom: tool listing POSTs to
the hub root with no auth) — config.yaml is the single source. Key
allowlists are updated by NAME via `/key/update`
(`object_permission.mcp_servers`), but the toolset rows are what gate
`/mcp` (see the toolsets section).

Tools: `memory_search(query, tag, limit)` — ranked matches with ~160-char
snippets, never full values; `memory_tags()` — tag vocabulary digest;
`memory_get/set/list/delete` — set takes `tags` (metadata preserved on
value-only updates). Scoring (exact key-segment > exact tag > substring
tag > value substring) is kept in parity between the hub's JS module and
the Python `litellm_mcp` package on :4001.

Discipline (AGENTS.local.md carries the policy): markdown owns durable
knowledge; memory holds small volatile facts only — one fact per key, the
key names the fact, tags required, documented-elsewhere → nowhere. Agents
self-nudge: call `memory_search`/`memory_tags` at the start of substantial
tasks. The `memory-nudge.js` plugin that automated this was removed
2026-10-03 — do not resurrect it. Its injected part lacked
id/sessionID/messageID, failing the message-storage schema and killing
every session's first message (2026-09-25 → 2026-10-03); schema-fixed, it
still glued `[memory nudge] …` text into user prompts (user verdict:
counterproductive).

Debugging notes: `/healthz` on the hub shows per-server state (a `failed`
memory server usually means `memory_api_key` didn't resolve). Redis
pubsub config-sync works again since 2026-09-26 — it had been silently
dead because hb's Redis hardening block carried `rename-command PUBLISH
""` (removed + service restarted). Only model-table writes
(`/model/new`, `/model/{id}/update`, `/model/delete`) publish
`config_change` events; `/config/update` general-settings params do NOT
— replicas pick those up via the ~30s DB poll. File-based config changes
still need a proxy restart.
