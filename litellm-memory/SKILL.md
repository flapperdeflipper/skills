---
name: litellm-memory
description: "Durable cross-session memory via the LiteLLM proxy (/v1/memory and the memory_* MCP tools). Use when saving, recalling, or managing persistent facts, decisions, and preferences for agents across machines and sessions."
license: MIT
---

## What this is

LiteLLM's memory API is a key-value store (PostgreSQL-backed, redis-cached) that
survives sessions and is shared by every agent that authenticates to the proxy.
Access is scoped by the calling key's user/team; the personal `flip` user is a
proxy admin and sees everything.

## Key conventions

- `opencode:global:*` — shared across all opencode sessions (any machine)
- `opencode:<project>:*` — scoped to one project (e.g. `opencode:homeassistant:*`)
- `user:*` — personal preferences (tone, tools, workflows)

Values are plain text; keep one fact per key, lead with the important words.
Never store passwords, tokens, or anything secret.

## Access paths

- **MCP (preferred for agents)**: `memory_get(key)`, `memory_set(key, value)`
  (upsert), `memory_list(key_prefix?)`, `memory_delete(key)` — served by the
  `litellm_mcp` stdio server through the proxy's MCP gateway (alias `memory`).
- **REST**: `GET/PUT/DELETE /v1/memory/<key>`, `GET /v1/memory?key_prefix=…`
  with `Authorization: Bearer <litellm key>`.

## Workflow

1. At session start, `memory_list("opencode:")` (or the project prefix) to
   recall context. Do not dump everything into the conversation — pull full
   values only for relevant keys.
2. During work, save durable decisions with `memory_set` as they are made
   (not at the end — sessions get interrupted).
3. Update by overwriting (PUT upserts); delete keys that are no longer true.
4. Long values are truncated by `memory_list`; use `memory_get` for full text.
