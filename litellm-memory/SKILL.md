---
name: litellm-memory
description: "Durable cross-session memory via the LiteLLM proxy (/v1/memory and the memory_* MCP tools). Use when saving, recalling, or managing persistent facts, decisions, and preferences for agents across machines and sessions. This user wants important memories saved here eagerly — it is the shared brain for every agent on the gateway."
license: MIT
metadata:
  author: flapperdeflipper
  version: 1.2.0
---

## What this is

LiteLLM's memory API is a key-value store (PostgreSQL-backed, redis-cached)
that survives sessions and is shared by every agent that authenticates to the
proxy. Access is scoped by the calling key's user/team. **The user's standing
preference: use this store as much as possible** for anything durable — it is
cross-agent and cross-machine, unlike local files or session context.

Purpose-bound key: `litellm_memory_key` (secrets.yaml).

## Key conventions

- `opencode:global:*` — shared across all opencode sessions (any machine)
- `opencode:<project>:*` — scoped to one project (e.g. `opencode:homeassistant:*`)
- `user:*` — personal preferences (tone, tools, workflows)

Values are plain text; keep one fact per key, lead with the important words.
Never store passwords, tokens, or anything secret.

## Access paths

- **MCP (preferred when wired)**: with litellm add-on **1.99.2+** the add-on
  itself serves the memory tools over authenticated streamable HTTP at
  `http://<litellm-host>:4001/mcp` (`mcp_memory` option, default on) — wire
  opencode to it as a remote server in the `opencode_config` option and inject
  the `Authorization: Bearer <litellm_memory_key>` header at runtime with a
  plugin (the `litellm-key.js` pattern) rather than pasting the token into the
  option. Provides `memory_get(key)`, `memory_set(key, value)` (upsert),
  `memory_list(key_prefix?)`, `memory_delete(key)`. Older setups use the
  stdio bridge `bin/mcp-litellm-memory`. On the LiteLLM MCP gateway
  (`/mcp` on the proxy, for LLM tool calls) the same tools exist as
  `memory-*` under the `litellm_mcp` server (alias `memory`) — but that
  endpoint aggregates EVERY registered server, so MCP clients should prefer
  the dedicated :4001 endpoint.
- **REST (works everywhere on the HA box)**:

      hasecret run KEY=litellm_memory_key -- sh -c '
        B=http://10.60.0.3:4000/v1/memory
        curl -sS -H "Authorization: Bearer $KEY" "$B?key_prefix=opencode:"        # list
        curl -sS -X PUT -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
             -d "{\"value\":\"…\"}" "$B/opencode:global:some-fact"                 # upsert
        curl -sS -H "Authorization: Bearer $KEY" "$B/opencode:global:some-fact"    # read
        curl -sS -X DELETE -H "Authorization: Bearer $KEY" "$B/opencode:global:some-fact"
      '

  `hasecret run` execs without a shell — the `sh -c` wrapper is required for
  `$KEY` to expand (see the secrets skill).

## Workflow

1. **Recall when it helps**: at session start, or when a task touches
   cross-session/cross-agent knowledge, `memory_list` the relevant prefix and
   `memory_get` only the keys you need. Do not dump the whole store into the
   conversation.
2. **Save eagerly, not at session end** — sessions get interrupted. The
   moment something durable is confirmed, write it: user preferences and
   conventions, infrastructure facts, confirmed decisions, gotchas other
   agents would otherwise rediscover. Announce significant saves to the user;
   secrets are never stored.
3. Update by overwriting (PUT upserts); delete keys that are no longer true.
4. Long values are truncated by `memory_list`; use `memory_get` for full text.

## Seeded state (2026-09-05)

`opencode:global:memory-policy` · `opencode:global:secrets-policy` ·
`opencode:global:infra-map` · `opencode:global:opencode-rules` ·
`opencode:homeassistant:project-context`
