---
name: home-infra
description: "Map of the personal home infrastructure: which git repos hold what (addons, skills, dotfiles), the deployed add-ons and shared components, how add-on images are built and published, where secrets live, and the key endpoints. Use before making changes to add-ons or publishing anything."
license: MIT
metadata:
  author: flapperdeflipper
  version: 1.1.0
---

## Repositories

| Repo | Holds |
|------|-------|
| `flapperdeflipper/addons` | All Home Assistant add-on sources. `builder.yml` CI builds changed add-ons on merge to master and publishes to Docker Hub `flapperdeflipper/addon-*`. Master is protected: changes go through PRs (2 required checks). |
| `flapperdeflipper/skills` | Agent skills. Canonical working copy: `/homeassistant/skills` (self-contained git repo, ignored by the HA config repo). Published to the LiteLLM skills gateway (`GET /public/skill_hub`) from GitHub. The copy sessions load, `/homeassistant/.opencode/skills/*`, is a tree of symlinks into the repo — editing the repo file updates both. |
| dotfiles (`/share/syncthing/dotfiles/profile`) | Per-machine agent config synced via syncthing: `.agents/`, `.claude/`, `.config/opencode/`, `.pi/agent/`. Skills there are the upstream source of the skills repo. |

`/homeassistant/addons/` is the **deployed copy** of the add-on sources; the
GitHub repo is where images are built from. Changes must land in both (edit
locally, then PR into the repo) — and every add-on change needs a version bump
in `config.yaml` plus a CHANGELOG entry.

## Deployed add-ons (/homeassistant/addons/)

`ha_opencode` (this add-on: certified OpenCode + OpenChamber web UI +
ha-mcp-server + hasecret + op CLI) · `litellm` (LLM proxy, MCP gateway,
skills hub) · `searxng_with_mcp` · `mosquitto` · `playwright-browser` ·
`terminal` · `isponsorblocktv`.

## Shared components

- **ha-mcp-server** — the full Home Assistant MCP toolset, in `/opt/ha-mcp-server`
  inside the opencode add-on; also servable over HTTP on 8927/tcp
  (`mcp_http_enabled` + bearer token) for sibling add-ons such as the LiteLLM
  MCP gateway. Ships with `hab` and `zigporter` companion CLIs.
- **litellm_mcp** — Python MCP package in the litellm add-on image
  (`/mcp_servers/litellm_mcp`): memory_get/set/list/delete + registry_list,
  spawned by the proxy; `LITELLM_MEMORY_KEY` (secret `litellm_memory_key`)
  scopes it.
- **mcp-litellm-memory** — `/homeassistant/bin/mcp-litellm-memory`: tiny stdio
  MCP bridge that exposes the memory tools directly in opencode sessions
  (wired via the add-on's `opencode_config` option).
- **hasecret** — `/homeassistant/bin/hasecret`, the only way to touch
  `/homeassistant/secrets.yaml` (see the secrets skill).
- **OpenChamber** — browser UI for OpenCode, pinned and Ingress-patched in the
  add-on; humans read past conversations at <https://opencode.pl4.dev>.

## Publishing an add-on

1. Edit under `/homeassistant/addons/<addon>/`, bump `version:`, CHANGELOG.
2. Branch + PR in `flapperdeflipper/addons`, wait for the two checks, merge.
3. CI builds and pushes `flapperdeflipper/addon-<name>:<version>` to Docker Hub.
4. Update the add-on in the Home Assistant UI.

## Secrets policy

No secret values in add-on options or config files. Add-on options either hold
secrets.yaml key names (litellm convention) or `!secret <key>` values (the
Supervisor resolves them). Everything resolves from `/homeassistant/secrets.yaml`
at start. Tokens are never logged. Tooling and rules: the `secrets` skill.

## Key infrastructure endpoints

- LiteLLM proxy: `http://10.60.0.3:4000` (internal), `https://llm.pl4.dev` (VPN)
- LiteLLM MCP gateway: `/mcp` on the proxy (memory/search/docs tools, bearer auth)
- LiteLLM memory API: `/v1/memory` on the proxy — key `litellm_memory_key`
- Skills hub: `GET /public/skill_hub` on the proxy
- Redis: `10.20.0.2:6379` (auth) — litellm cache
- PostgreSQL: external, via `litellm_database_dsn` — litellm DB (memory, keys, spend)
- OpenChamber (read past conversations): `https://opencode.pl4.dev`; agent-side
  read-only copy in `/data/.local/share/opencode/opencode.db` (sqlite, tables
  `session`/`message`/`part` — never write, never touch `credential`/`account*`)
