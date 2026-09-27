---
name: docstore
description: "The agent document store on the couchdb add-on (MCP server 'docstore'): versioned, queryable JSON documents for handoffs, work-queue tasks, reports and durable dossiers, with enforced _id grammar, audit fields and TTL sweeper. Use for cross-session/cross-agent structured data too big or too query-shaped for LiteLLM memory. Never for the Obsidian vault database."
license: MIT
metadata:
  author: flapperdeflipper
  version: 1.0.0
---

# Skill: docstore

# Docstore

Structured, versioned, queryable documents shared across agents and
sessions, served by the **couchdb add-on** (CouchDB) through the MCP
gateway server **`docstore`** (mcp-hub forwarder → couchdb :5985). Writes
are validated in code — the registry allowlist, `_id` grammar, audit
fields and TTL stamping are enforced by the server, not by prose.

## Triage: what goes where

| Need | Use |
|---|---|
| Small volatile fact, key names the fact | LiteLLM `memory` (`memory_set`, tags) |
| Working docs, plans, handover files for THIS task | `/share/scratchpad/<agent>/<dated-dir>` |
| Durable knowledge, procedures, conventions | markdown in the repo/skill it describes |
| Time series, metrics | VictoriaMetrics (PromQL) |
| **Structured/queryable/versioned documents across sessions & agents; work queues with claim semantics; dated reports and handoffs; durable per-topic dossiers** | **docstore (this skill)** |

Rule of thumb: if it needs Mango queries, TTLs, multi-writer claims, or
outlives a session but is data (not documentation) — docstore.

## Data model

Databases and types are fixed by the registry
(`/addon_configs/4e94d283_couchdb/couchdb/docstore/registry.json` — edit +
restart the add-on to change; never add the `obsidian` vault database):

| db | type(s) | `_id` grammar | TTL |
|---|---|---|---|
| agent_handoffs | handoff | `handoff/YYYY-MM-DD-<slug>` | 90 d |
| agent_tasks | task | `task/<queue>/<id>` | 30 d after done |
| agent_reports | report | `report/YYYY-MM-DD-<slug>` | 180 d |
| agent_memory | dossier, note | `dossier/<topic>`, `note/<topic>` | none |

Semantics:

- The `_id` namespace prefix **is** the type — a `handoff/…` id carries a
  handoff; the pattern is enforced.
- Writes stamp `type`, `created`/`updated`, `agent`, `session`. Pass your
  identity: `agent: "opencode"`, `session: "<session-id>"`.
- TTL: `expires` is stamped per type unless you set it explicitly;
  `"expires": null` opts out. Tasks expire from their `done` timestamp.
  The sweeper purges hourly (see the add-on log).

## Tools (MCP server `docstore`)

- `doc_get(db, id)`
- `doc_put(db, id, doc, agent?, session?)` — create; validation as above
- `doc_update(db, id, doc, rev, agent?, session?)` — replace body at rev
- `doc_delete(db, id, rev)`
- `doc_query(db, selector, limit?, fields?)` — Mango, capped at 200
- `task_claim(queue, agent?)` — next todo → in_progress (atomic-ish, rev retry)
- `task_complete(db, id, agent?)` — stamps done + expiry

Task lifecycle: `status: todo → in_progress → done`, `queue` field routes
claims. Create tasks with `doc_put` (`status: "todo"`, `queue: "<name>"`,
payload fields of your choosing), coordinate via `task_claim`.

Verify writes: `doc_put` then `doc_get` when the content matters.

## Examples

```json
{"server_id": "docstore", "name": "doc_put", "arguments": {
  "db": "agent_reports", "id": "report/2026-09-26-docstore-rollout",
  "doc": {"title": "Docstore rollout", "tags": ["infra", "couchdb"]},
  "agent": "opencode", "session": "2026-09-26-docstore"}}
```

```json
{"server_id": "docstore", "name": "doc_query", "arguments": {
  "db": "agent_memory", "selector": {"type": "dossier", "tags": {"$in": ["zigbee"]}}}}
```

Batch operations (bulk delete, bulk edit): use the Fauxton UI, not the
tools — preview before deleting there.

## Reviewing and managing data (humans)

- HA sidebar → **CouchDB** panel (admin-only ingress; Fauxton with admin
  rights behind the HA login), or directly `http://<host>:5984/_utils`
  (browser Basic-auth as `admin` or `vault`).
- The `agent` login works for direct database URLs but cannot list
  databases (`_all_dbs` is server-admin only).
- No recycle bin: deletion recovery is a Home Assistant backup
  (`/addon_configs/…/couchdb/` is included).

## Guardrails

- Never read/write the `obsidian` database — client-side encrypted
  LiveSync vault; junk documents there corrupt sync.
- One document = one coherent item; tags are for queries.
- `expires: null` is a deliberate decision, not a default.
- Changing the registry or credentials: couchdb add-on options are
  leading — every start re-asserts databases, users, rights (levels
  converge, e.g. member↔admin moves) and passwords; removals never revoke.
