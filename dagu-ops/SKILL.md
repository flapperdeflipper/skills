---
name: dagu-ops
description: "Operating a running Dagu instance through its Web UI (dashboard, execution monitoring, history, logs) and REST API (start/stop/retry, status and history queries, log retrieval, CI/CD integration). Use for managing or monitoring Dagu; DAG YAML authoring belongs to the dagu skill."
license: MIT
---

# Dagu ops

Router. Read only the guide the task needs: `<guide>/GUIDE.md` in this skill's
directory.

| Guide | Read when |
|---|---|
| `rest-api` | Programmatic workflow management over HTTP: start/stop/retry/restart, status and history queries, log retrieval, DAG CRUD, search, CI/CD and webhook integration |
| `webui` | Browser operations: dashboard, manual start/stop, real-time execution monitoring, history and retries, DAG visualization, troubleshooting stuck workflows |

## This install: `dagu_read` through the gateway returns placeholders

Dagu's MCP server puts every read payload except `dags` in
`structuredContent` + a `resource_link` (their spec 021: the text block is
exactly `Dagu read completed.`), and the LiteLLM gateway bridge drops
non-text content. In-session MCP reads are therefore empty for `dag_spec`,
`runs`, `run`, `run_logs`, `step_log`, `dag_search`, `wiki_page`, ... while
`dags`, `dagu_execute` and `dagu_change` work. Diagnosed 2026-10-01
(Dagu 2.18.1 patched build, litellm-database v1.102.1).

Read directly — same MCP server, full payloads. Stateless calls are refused;
initialize first and reuse the returned session id:

```bash
hasecret run KEY=dagu_mcp_api_key -- sh -c '
  U=https://work.pl4.dev/mcp; H="Authorization: Bearer $KEY"
  A="Accept: application/json, text/event-stream"; J="Content-Type: application/json"
  curl -sS -D /tmp/h -X POST $U -H "$H" -H "$J" -H "$A"     -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-06-18\",\"capabilities\":{},\"clientInfo\":{\"name\":\"cli\",\"version\":\"0\"}}}" >/dev/null
  SID=$(grep -i "^mcp-session-id:" /tmp/h | tr -d "\r" | cut -d" " -f2)
  curl -sS -X POST $U -H "$H" -H "$J" -H "$A" -H "Mcp-Session-Id: $SID" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"dagu_read\",\"arguments\":{\"target\":\"step_log\",\"name\":\"<DAG>\",\"dagRunId\":\"<run>\",\"stepName\":\"<step>\"}}}"
'
```

The payload is in `.result.structuredContent` of the JSON-RPC result. The
key is scoped to the MCP surface — the REST API under `/api/v1` refuses it
("API key is not allowed for this surface").

Adapted from [vinnie357/claude-skills](https://github.com/vinnie357/claude-skills/tree/main/plugins/tools/dagu/skills) (MIT, Vinnie Mazza; see LICENSE), which packages
docs.dagu.cloud content accessed 2025-11-15. The upstream `workflows` facet
was skipped — the vendored `dagu` skill tracks the installed CLI version and
is the authority for DAG YAML syntax. These guides may lag the running server
(upstream was last checked against v2.11.1): verify field names and endpoints
against the live instance when exactness matters.
