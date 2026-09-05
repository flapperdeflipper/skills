---
name: home-assistant-ops
description: "Operate THIS Supervised install and its opencode/litellm stack: Supervisor REST API v2 options, opencode add-on config, litellm wiring, skills hub publishing. Not for HA YAML, dashboards, troubleshooting, or Zigbee/ESPHome - other skills cover those."
license: MIT
---

# Home Assistant ops: this installation

Supervised install on Debian (HA 2026.8, Supervisor 2026.08). Config lives in
`/homeassistant` (packages under `configuration/`). Repos, publishing pipeline
and secrets policy: see the `home-infra` skill. LiteLLM MCP gateway: see the
`litellm-gateway` skill.

## Supervisor REST API: v2 options format

`POST http://supervisor/addons/{slug}/options` (Bearer `$SUPERVISOR_TOKEN`
from inside an add-on) accepts ONLY the nested body:

```json
{"options": { "...complete user option set..." }}
```

- A flat v1 body (`{"font_size": 14}`) fails with the misleading error
  `extra keys not allowed @ data['font_size']` even though the key is valid.
  Allowed siblings of `options`: `boot`, `network`, `auto_update`,
  `audio_input/output`, `ingress_panel`, `watchdog`.
- ALWAYS send the complete option set. Partial `options` validate against
  config.yaml defaults, not current values — omitted options reset. Read
  current options from `GET /addons/{slug}/info` → `.options`, merge, POST.
- `/data/options.json` inside an add-on container is written at container
  start only — NOT a live view. Verify writes via the info endpoint.
- The add-on's own SUPERVISOR_TOKEN may update its own options; store/repo
  admin endpoints return 403.
- Core's hassio proxy is gone in this version: websocket `hassio/api` is an
  unknown command and `/api/hassio/*` returns 401. Talk to the Supervisor
  directly, or to Core at `http://172.30.32.1:8123` with `HA_ACCESS_TOKEN`
  (that token is rejected on the `/supervisor/core` proxy path).
- Reference: `supervisor/api/apps.py` `SCHEMA_OPTIONS` at the running tag.

## ha_opencode: what is regenerated and what persists

| Path | Written by | Editable |
|------|-----------|----------|
| `/data/.config/opencode/opencode.json` | add-on init, EVERY start | never — edits are clobbered |
| `/data/.config/opencode/config.json` | init, from the `opencode_config` add-on option | via the option, not the file |
| `/data/.config/opencode/skills/home-assistant-*/` | deploy script, hash-tracked in `/data/.opencode_managed_assets.json` | hand edits block refresh, never survive images updates |
| `/data/.config/opencode/plugin/` | nobody — user-owned | yes |
| `/data/.env_vars` | init, from the `env_vars` option (`{name, value}`) | via the option |

Schema note: `env_vars` here is plain name/value pairs. The `secret:` field
(secrets.yaml key reference) that the litellm add-on supports does NOT exist
in ha_opencode — resolve secrets via a plugin instead (below).

## The litellm model provider in opencode

- Provider `litellm` (openai-compatible) points at `https://llm.pl4.dev/v1`;
  models and context limits come from `/v1/models` and `/v1/model/info`.
- The API key is injected at startup by `/data/.config/opencode/plugin/litellm-key.js`,
  which reads `litellm_ha_key` from `/homeassistant/secrets.yaml`. secrets.yaml
  stays the single source; rotating the key needs no opencode change.
- Provider + plugin registration live in the `opencode_config` add-on option.
  Changing models = update that option (complete set, v2 format), sync
  `/data/.config/opencode/config.json` to match, restart opencode sessions.
- Model aliases must match the litellm `model_list` in
  `/homeassistant/litellm/config.yaml` exactly.

## Publishing skills to the LiteLLM hub

Skill content is pulled from git by consumers, so edits to a registered skill
propagate on their own. What does NOT sync automatically: new skills and hub
metadata (description/version). After merging to `flapperdeflipper/skills`:

```bash
/homeassistant/skills/scripts/sync-skill-hub.sh          # dry run
/homeassistant/skills/scripts/sync-skill-hub.sh --apply  # POST new, PUT changed
```

Master key comes from `litellm_master_key` in secrets.yaml. Registry
endpoints: `GET/POST /claude-code/plugins`, `PUT/DELETE
/claude-code/plugins/{name}`. Note: hub descriptions were originally
registered shortened — an `--apply` sync replaces them with the full
frontmatter descriptions.

## ESPHome and Zigbee here

- ESPHome Device Builder add-on is the source of truth; prefer the native
  `esphome_*` MCP tools over `hab esphome`. Device configs are NOT reachable
  from opencode (no `/addon_configs` access).
- Zigbee runs on Zigbee2MQTT; renames must cascade via `zigporter`. Workflows
  live in the `home-assistant-zigbee-esphome` skill.
- Entity-level gotchas (mqtt twins, spare phones) live in the opencode
  decision notes, not here.
