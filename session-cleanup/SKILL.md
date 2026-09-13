---
name: session-cleanup
description: "Remove stored opencode sessions on the HA box when they are finished, superseded or unused: run the session-cleanup tool (archived/superseded/stale classification, dry-run by default, transcript export, API-only deletion), extract durable decisions into slopclanker/LiteLLM memory/HA decision notes BEFORE deleting, then apply. Use when asked to clean up, prune, or reclaim space from old agent sessions."
license: MIT
metadata:
  author: flapperdeflipper
  version: 1.0.0
---

# Session cleanup

Old opencode sessions (terminal, headless, OpenChamber, subagents) accumulate
in `/data/.local/share/opencode/opencode.db`. This skill is the sanctioned way
to prune them. The tool does the mechanics; the agent does the judgement —
decisions found in doomed sessions must be preserved BEFORE deletion.

## The tool

`/usr/local/bin/session-cleanup` (opencode add-on ≥ 2.11.0):

| Class | Meaning |
|---|---|
| `archived` | finished in the UI (`time_archived` set) — always eligible |
| `superseded` | a child session took over (continue/fork/compact leaves the parent behind) — eligible when also stale, or any age with `--superseded-any-age` |
| `stale` | no activity for `--min-age-days` (default 30) |

Hard rules baked into the tool — do not work around them:

- The sqlite database is read **read-only**; deletion goes only through the
  local opencode server API (`DELETE /session/{id}`). Never write the DB,
  never touch `credential`/`account*` tables.
- Shared sessions are never deleted. `--keep ses_ID` protects ids — **always
  pass your own session id** (find it with `sessions_list`, marked
  `<-- this session`).
- `--apply` exports every transcript to
  `/data/.local/share/opencode/session-archive/cleanup-<stamp>/` before
  deleting. Exports are the fallback archive, not the primary decision store.
- Dry-run by default. `--json` for machine-readable output.

## Workflow

1. **Report**: `session-cleanup --json` — never start with `--apply`.
   Adjust `--min-age-days` to what the user asked for.
2. **Triage**: for each eligible session that had real work (`tool_calls` or
   several messages), read it with `sessions_get` (or the export-friendly
   transcript via the API). Subagent one-shots and trivial chats need nothing.
3. **Preserve decisions** — anything that outlives the session:
   - Cross-agent or home-level decisions → **slopclanker** note or wiki page
     (`slopclanker_*` MCP tools; if the MCP server is not wired, the REST API
     at `http://10.20.0.3:8090/api/…` with the token file
     `/data/.config/opencode/slopclanker.token` — see the slopclanker skill).
   - Agent conventions and preferences → **LiteLLM memory** (`opencode:*`
     keys) — see the litellm-memory skill.
   - Home Assistant installation decisions → HA **decision notes**
     (`remember_decision`, with user approval) — see the AGENTS.md rules.
   Nothing durable found → say so explicitly in the final report.
4. **Apply**: `session-cleanup --apply --keep <your ses_ID>` (add
   `--only ses_ID` to prune a subset). Deleting is irreversible; exports land
   in the session-archive directory.
5. **Report back**: what was deleted (count + reasons), what was stored where
   (slopclanker/memory/decision-note links or keys), where the exports are.

## Safety

- Ask before running `--apply` unless the user explicitly asked for the
  cleanup in this conversation — this deletes conversations a human may still
  want to re-read at <https://opencode.pl4.dev>.
- When in doubt about a session, keep it (`--keep`) and mention it.
- The tool fails closed (exit 2) if the opencode server is unreachable — fix
  that, never delete rows behind the server's back.
