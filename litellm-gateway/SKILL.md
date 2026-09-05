---
name: litellm-gateway
description: "The LiteLLM proxy as the single MCP gateway: one endpoint for memory, search, docs, and browser tools. Use when wiring agents to tools, discovering available MCP servers, or adding new ones."
license: MIT
---

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
| — | `playwright` | browser automation over CDP |

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
