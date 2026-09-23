<!-- source: MIT -->
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
- Provider + plugin registration live in the config drop-ins
  (`/addon_configs/4e94d283_ha_opencode/*.json`, deep-merged into
  `/data/.config/opencode/config.json` at add-on start — see that folder's
  README). Changing models = edit the drop-in, then regenerate the merged
  file (see the litellm-gateway guide's zai section) and restart opencode.
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
- Entity-level gotchas: ESPHome conventions and the mqtt-discovery-off
  guard live in `/homeassistant/esphome/AGENTS.md`; device knowledge (kiosk,
  BLE presence, AppDaemon) in the `home-devices` skill. Decision notes were
  retired 2026-09-20.

## Supervisor quirks (HA Supervised 2026.09.2, 2026-09-19)

- `POST /addons/4e94d283_ha_openchamber/options` rejects EVERY key with
  "extra keys not allowed" — the Supervisor's validation schema for that one
  add-on is empty (empty body `{}` validates; other add-ons validate fine).
  Suspected metadata-cache corruption; also blocks changing
  lan_allowed_remotes via UI/API.
- `hab backup create` fails with `required key not provided at 'agent_ids'`
  (hab bug) — use the Supervisor API or UI instead.
- Automatic daily full backups DO exist (~05:40, 27 addons + ssl + share) —
  the resolution issue `no_current_backup` is stale/misleading.

## Python venvs

Never create venvs inside `/share/syncthing/projects/*` — that tree is
syncthing-shared across CPU architectures (x86_64 + ARM64); a venv there
breaks the other machines. Use `/data/venvs/<project-name>`.

## Agent image slimming (2026-09-22, agent-base 1.1.0)

- agent-base carries a CURATED apt set: imagemagick AND ffmpeg are
  deliberately kept; ~38 one-shot tools (awscli, nmap, rclone, cmake,
  bats, …) were deliberately REMOVED — do not assume they exist, do not
  casually re-add.
- chromium is NOT in agent-base; only ha_opencode installs a chromium+fonts
  layer for its MCP screenshot tool.
- playwright-browser add-on (2026.09.21+): Debian chromium + nginx under s6,
  built on base-debian:trixie — no Playwright FROM-line bumps; browser
  updates ride Debian package updates via CalVer-dated rebuilds. Chromium
  only (no Firefox/WebKit). MCP bridges connect over CDP.
- Full report: `/share/scratchpad/opencode/2026-09-21-image-slimming/REPORT.md`

## OpenChamber add-on: stopped

The ha_openchamber add-on is deliberately stopped to save memory (2026-09-23);
start it from the HA UI when the web UI is needed, and stop it after. Its
agent-MCP plugin is removed from opencode, so sessions no longer carry
openchamber tools. Known issues if it comes back: `opencode serve` leaks
EventTarget listeners per web-client reconnect (upstream #28492/#46035,
unfixed in 1.18.31 — watch #46035 and bump the certified pin when fixed);
Supervisor REST options-writes are broken for it (empty validation schema,
see quirks above). Build history: PRs #116/#118/#122/#130.
