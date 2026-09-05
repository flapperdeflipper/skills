---
name: home-infra
description: "Map of the personal home infrastructure: which git repos hold what (addons, skills, dotfiles), how add-on images are built and published, and where secrets live. Use before making changes to add-ons or publishing anything."
license: MIT
---

## Repositories

| Repo | Holds |
|------|-------|
| `flapperdeflipper/addons` | All Home Assistant add-on sources (`ha_opencode`, `litellm`, `searxng_with_mcp`, …). `builder.yml` CI builds changed add-ons on merge to master and publishes to Docker Hub `flapperdeflipper/addon-*`. Master is protected: changes go through PRs (2 required checks). |
| `flapperdeflipper/skills` | Agent skills. Canonical working copy: `/homeassistant/skills` (self-contained git repo, ignored by the HA config repo). Published to the LiteLLM skills gateway from GitHub. |
| dotfiles (`/share/syncthing/dotfiles/profile`) | Per-machine agent config synced via syncthing: `.agents/`, `.claude/`, `.config/opencode/`, `.pi/agent/`. Skills there are the upstream source of the skills repo. |

`/homeassistant/addons/` is the **deployed copy** of the add-on sources; the
GitHub repo is where images are built from. Changes must land in both (edit
locally, then PR into the repo) — and every add-on change needs a version bump
in `config.yaml` plus a CHANGELOG entry.

## Publishing an add-on

1. Edit under `/homeassistant/addons/<addon>/`, bump `version:`, CHANGELOG.
2. Branch + PR in `flapperdeflipper/addons`, wait for the two checks, merge.
3. CI builds and pushes `flapperdeflipper/addon-<name>:<version>` to Docker Hub.
4. Update the add-on in the Home Assistant UI.

## Secrets policy

No secret values in add-on options or config files. Add-on options either hold
secrets.yaml key names (litellm convention) or `!secret <key>` values (the
Supervisor resolves them). Everything resolves from `/homeassistant/secrets.yaml`
at start. Tokens are never logged.

## Key infrastructure endpoints

- LiteLLM proxy: `http://10.60.0.3:4000` (internal), `https://llm.pl4.dev` (VPN)
- Redis: `10.20.0.2:6379` (auth) — litellm cache
- PostgreSQL: external, via `litellm_database_dsn` — litellm DB (memory, keys, spend)
