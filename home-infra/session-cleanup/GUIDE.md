<!-- source: flapperdeflipper, MIT -->
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
3. **Preserve decisions** — anything that outlives the session goes to
   **markdown** (policy since 2026-09-23; LiteLLM memory and HA decision
   notes are retired): critical constraints → `/homeassistant/AGENTS.local.md`
   guardrails; topic knowledge → the matching skill guide in the skills repo;
   one-off history → the scratchpad report for the task. Nothing durable
   found → say so explicitly in the final report.
4. **Apply**: `session-cleanup --apply --keep <your ses_ID>` (add
   `--only ses_ID` to prune a subset). Deleting is irreversible; exports land
   in the session-archive directory.
5. **Report back**: what was deleted (count + reasons), what was stored
   where (file paths), where the exports are.

## Safety

- Ask before running `--apply` unless the user explicitly asked for the
  cleanup in this conversation — this deletes conversations a human may still
  want to re-read at <https://opencode.pl4.dev>.
- When in doubt about a session, keep it (`--keep`) and mention it.
- The tool fails closed (exit 2) if the opencode server is unreachable — fix
  that, never delete rows behind the server's back.
