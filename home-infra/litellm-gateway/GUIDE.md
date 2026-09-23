<!-- source: flapperdeflipper, MIT -->
## One endpoint for everything

All agents (opencode, Claude Code, anything MCP-capable) use a single MCP
endpoint instead of registering servers individually:

- Internal (HA network): `http://10.60.0.3:4000/mcp`
- External (VPN, SSO-protected for humans): `https://llm.pl4.dev/mcp`
- Auth: `Authorization: Bearer <litellm virtual key>` — never SSO for agents

## Registered servers and aliases

| Alias | Server | Provides |
|-------|--------|----------|
| `memory` | `litellm_mcp` | memory_get/set/list/delete + registry_list discovery |
| `search` | `searxng` | web + GitHub code search (PAT-authenticated) |
| `docs` | `context7` | up-to-date library documentation |
| — | `playwright` | browser automation over CDP (endpoint via `PLAYWRIGHT_CDP_ENDPOINT` env var) |
| — | `victoriametrics` | PromQL queries against Victoria Metrics (`prometheus-mcp-server`, basic auth from secrets) |
| — | `homeassistant` | full ha-mcp-server (65 tools: state, control, safe config writes, supervisor, ESPHome/zigporter/hab) served by the opencode add-on over HTTP at 10.20.0.3:8927 (stateless, bearer token) |
| — | `homeassistant_native` | curated Assist/entity-control tools straight from Core's own MCP endpoint |

Tool names arrive namespaced (`litellm_mcp-memory_get`, `searxng-*`, …).

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

    curl -X POST http://10.60.0.3:4000/mcp-rest/tools/call \
      -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
      -d '{"server_id":"litellm_mcp","name":"memory_list","arguments":{}}'

Servers are registered in `/homeassistant/litellm/config.yaml` under
`mcp_servers:`. Gotcha: stdio children get a **scrubbed environment** —
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

## Memory store: retired from opencode (2026-09-23)

The LiteLLM memory API (`/v1/memory`) and its MCP tools still exist on the
proxy for other agents, but opencode no longer wires them in and the opencode
keys were migrated to markdown (skills + AGENTS.local.md) — see
`/share/scratchpad/opencode/2026-09-23-memory-value-analysis/` for the
migration report and the full store backup. Don't write new opencode memory
keys; put durable knowledge in the skills repo or AGENTS.local.md instead.
