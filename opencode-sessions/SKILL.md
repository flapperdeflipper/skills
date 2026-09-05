---
name: opencode-sessions
description: "Look up and read previous opencode conversations: which sessions exist, what was done or decided in them. Use when past-session history is needed — via the sessions_list/sessions_get tools inside opencode, or the read-only sqlite copy on the Home Assistant box. Also covers installing the sessions plugin on a machine."
license: MIT
metadata:
  author: flapperdeflipper
  version: 1.0.0
---

# Previous opencode sessions

Three access paths. Pick by where the agent runs:

| Where | Use |
|---|---|
| Inside opencode (any machine) | `sessions_list` / `sessions_get` tools |
| On the HA box, outside opencode | read-only sqlite: `/data/.local/share/opencode/opencode.db` |
| Human | <https://opencode.pl4.dev> (OpenChamber web UI) |

## Inside opencode: the sessions tools

Custom plugin: `github.com/flapperdeflipper/opencode-plugins`
(`plugins/sessions/sessions.js`). Loaded globally, so every session — any
project, TUI or headless — has both tools.

- `sessions_list(query?, limit?)` — sessions newest-first: id, title, model,
  last update, directory. `query` is a case-insensitive substring against
  title and directory. The current session is marked `<-- this session`.
- `sessions_get(session_id, limit?)` — transcript of one session: role,
  timestamp and text per message, `[tool: name]` markers for tool calls.
  Reasoning parts and diffs are skipped. When truncated, the most recent
  messages are kept and the omission is noted — raise `limit` for more.

Typical flow: `sessions_list` with a keyword → pick the id → `sessions_get`.
Session ids look like `ses_…`; titles are auto-generated from the first
prompt, so search by topic words.

## Outside opencode: read-only sqlite (HA box)

For agents not running inside opencode (scripts, other add-ons). The JSON
payloads live in the `data` columns of `message` and `part`:

```bash
python3 -c '
import sqlite3
con = sqlite3.connect("file:/data/.local/share/opencode/opencode.db?mode=ro", uri=True)
for sid, title in con.execute("SELECT id, title FROM session ORDER BY time_updated DESC LIMIT 10"):
    print(sid, title)
'
```

Tables: `session` (id, title, directory, time_updated), `message` (session_id,
data with role), `part` (message_id, data with type/text). Always open with
`mode=ro`. **Never write to this database and never touch the
`credential`/`account*` tables.**

The equivalent REST API also works locally, unauthenticated:
`curl http://127.0.0.1:4096/session` (add `/session/{id}/message` for the
transcript).

## Installing the plugin on a machine

```bash
git clone https://github.com/flapperdeflipper/opencode-plugins.git
cd opencode-plugins && npm install
ln -s "$PWD/plugins/sessions/sessions.js" ~/.config/opencode/plugin/sessions.js
```

Notes:

- Plugin directory is `plugin/` (singular) on opencode ≤1.18, `plugins/` on
  newer versions — check which exists.
- The plugin imports `@opencode-ai/plugin`; `npm install` in the clone makes
  that resolvable through the symlink. Not published to npm (deliberate).
- Plugins load at opencode startup: new sessions pick them up immediately; a
  long-running `opencode serve` adopts them only after restart.
