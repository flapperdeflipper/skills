<!-- source: flapperdeflipper, MIT -->
## Repositories

| Repo | Holds |
|------|-------|
| `flapperdeflipper/addons` | All Home Assistant add-on sources. `builder.yml` CI builds changed add-ons on merge to master and publishes to Docker Hub `flapperdeflipper/addon-*`. Master is protected: changes go through PRs (2 required checks). |
| `flapperdeflipper/skills` | Agent skills. Canonical working copy: `/homeassistant/skills` (self-contained git repo, ignored by the HA config repo). Published to the LiteLLM skills gateway (`GET /public/skill_hub`) from GitHub. The copy sessions load, `/homeassistant/.opencode/skills/*`, is a tree of symlinks into the repo — editing the repo file updates both. |
| `flapperdeflipper/appdaemon-apps` | AppDaemon apps + config (private, still on `master`). Source of truth; agent checkout `/share/worktrees/appdaemon-apps`. Deployed copy `/addon_configs/a0d7b954_appdaemon` via `git archive master \| tar -x -C` overlay — apps hot-reload, `appdaemon.yaml` needs an add-on restart. AD quirks and landmines: the `home-devices` appdaemon guide. |
| dotfiles (`/share/syncthing/dotfiles/profile`) | Per-machine agent config synced via syncthing: `.agents/`, `.claude/`, `.config/opencode/`, `.pi/agent/`. Skills there are the upstream source of the skills repo. |

`/homeassistant/addons/` is the **deployed copy** of the add-on sources; the
GitHub repo is where images are built from. Changes land via PR from a
`/share/worktrees` worktree (below) — and every add-on change needs a version
bump in `config.yaml` plus a CHANGELOG entry. The main checkout usually sits
on the human's in-flight feature branch: never branch, commit or rebase there.

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
- **agent-base** — `flapperdeflipper/agent-base` (checkout
  `/homeassistant/agent-base`, nested repo like addons/skills): the shared
  base image `ghcr.io/flapperdeflipper/agent-base:<semver>` (cosign-signed)
  that ha_opencode, ha_openchamber and terminal build FROM via an
  ARG-indirected pin (invisible to dependabot). Carries Node 24, certified
  opencode, hab, zigporter, yq, op CLI, cosign, and a skills snapshot under
  /opt/skills (SKILLS_REF pin, `skills-update` to refresh). Update flow: tag
  vX.Y.Z in agent-base -> CI publishes image -> update-addons.yml opens an
  automated roll-up PR in flapperdeflipper/addons -> merge -> rebuild add-ons.
  Master protected by contract tests + build.
- **litellm-memory in opencode** — REMOVED 2026-09-23: the plugin and the
  opencode memory keys were retired in favour of markdown (skills +
  AGENTS.local.md). The proxy-side memory API still exists for other agents;
  migration report and full store backup:
  `/share/scratchpad/opencode/2026-09-23-memory-value-analysis/`.
- **hasecret** — `/homeassistant/bin/hasecret`, the only way to touch
  `/homeassistant/secrets.yaml` (see the secrets skill).
- **OpenChamber** — browser UI for OpenCode, pinned and Ingress-patched in the
  add-on; humans read past conversations at <https://opencode.pl4.dev>.

## Publishing an add-on

1. Edit in a `/share/worktrees` worktree (see below), bump `version:`, CHANGELOG.
2. Branch + PR in `flapperdeflipper/addons`, wait for the two checks, merge.
3. CI builds and pushes `flapperdeflipper/addon-<name>:<version>` to Docker Hub.
4. Update the add-on in the Home Assistant UI (agent sessions die with the restart).

## Add-on worktrees (/share/worktrees)

Agent work on the addons repo happens in throwaway worktrees, never in the
main checkout:

    git -C /homeassistant/addons worktree add /share/worktrees/addons-N -b feature/<what> origin/master

- **Naming** follows the existing entries: `addons`, `addons-2`, `addons-3`, …
- **Branch from `origin/master`**, never local `master` — it lags behind.
  `git fetch` over SSH fails in this container (no key); the origin refs stay
  current anyway, and `gh api` can verify master when in doubt.
- **Tests**: a fresh worktree has no `node_modules`; run
  `npm ci --include=dev` — the container's `NODE_ENV=production` silently
  skips devDependencies (vitest) otherwise.
- **Cleanup after merge**: `git -C /homeassistant/addons worktree remove
  /share/worktrees/addons-N` (add `--force` for untracked `node_modules`),
  then `git branch -D feature/<what>` — plain `-d` refuses while local
  master hasn't caught up.

## Agent scratchpad (/share/scratchpad)

Agent documents (plans, handovers, research notes, reports) live under
`/share/scratchpad/<agent>/<YYYY-MM-DD-task-slug>/` — never in the HA config
repo. Worktrees are for code; the scratchpad is for documents. Isolation
rules (own namespace only, one dated dir per task, everything else
read-only, no cleanup without the human): `/share/scratchpad/README.md`.
`opencode/imported/` holds the docs migrated from `/homeassistant/opencode/`
when that directory was removed on 2026-09-20.

## Secrets policy

No secret values in add-on options or config files. Add-on options either hold
secrets.yaml key names (litellm convention) or `!secret <key>` values (the
Supervisor resolves them). Everything resolves from `/homeassistant/secrets.yaml`
at start. Tokens are never logged. Tooling and rules: the `secrets` skill.

## Key infrastructure endpoints

- LiteLLM proxy: `http://10.60.0.3:4000` (internal), `https://llm.pl4.dev` (VPN)
- LiteLLM MCP gateway: `/mcp` on the proxy (memory/search/docs tools, bearer auth)
- LiteLLM memory API: `/v1/memory` on the proxy — key `litellm_memory_key`
  (retired for opencode use 2026-09-23; still available to other agents)
- Skills hub: `GET /public/skill_hub` on the proxy
- Redis: `10.20.0.2:6379` (auth) — litellm cache
- PostgreSQL: external, via `litellm_database_dsn` — litellm DB (memory, keys, spend)
- OpenChamber (read past conversations): `https://opencode.pl4.dev`; agent-side
  read-only copy in `/data/.local/share/opencode/opencode.db` (sqlite, tables
  `session`/`message`/`part` — never write, never touch `credential`/`account*`)
