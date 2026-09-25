<!-- migrated from LiteLLM memory 2026-09-23 (was opencode:homeassistant:appdaemon_quirks + maintenance_todo_app) -->
# AppDaemon in this install

Add-on 0.19.2 = **AD 4.5.13**. Source of truth:
`flapperdeflipper/appdaemon-apps` (agent checkout
`/share/worktrees/appdaemon-apps`, MR workflow, CI runs ruff + yamllint
+ pytest). Deployed copy: `/addon_configs/a0d7b954_appdaemon` — a plain
directory (never git there), updated with
`git archive master | tar -x -C <dir>` overlay. `apps/` + `apps.yaml`
hot-reload; `appdaemon.yaml` changes need an add-on restart.

## Plugin quirks (learned 2026-09-20, revised 2026-09-25)

1. MQTT events arrive as event name `MQTT_MESSAGE` in the plugin
   namespace, not `mqtt`. `client_topics` subscribe at CONNECT time, so
   retained messages arrive BEFORE app listeners register — replay via
   `call_service("mqtt/subscribe", topic=...)` in a sweep. Filter with
   native `listen_event(..., wildcard=...)`, not hand-rolled fnmatch.
   (Topics narrowed 2026-09-25 from `#` to the two filters in use.)
2. Since AD 4.5 `call_service` RETURNS service responses (sync callbacks
   included; shape `["result"]["response"][<entity_id>]`). The old
   REST Supervisor-proxy workaround is deleted. `get_error_log` stays
   websocket-only — HA 2026.9 removed the REST `/api/error_log` route.
3. App-level namespace in apps.yaml must be `default` for HA state; a per-app
   MQTT listener namespace must be passed separately (`plugin_namespace` key)
   to avoid variable collision.
4. `appdaemon.yaml` `!secret appdaemon_mqtt_*` refs point at the HA
   secrets file. If mosquitto system-user passwords ever rotate, Z2M AND
   appdaemon both break until secrets are updated.

## set_state landmines (AD 4.5.13, verified 2026-09-25)

1. AD merges the HA write-back into stored attributes, leaking
   `last_changed`/`last_reported`/`context` into entities; HA 2026.9 then
   rejects merged writes with 400. Use `set_state(..., replace=True)` for
   app-owned entities — the first write heals already-poisoned attributes.
2. `utils.clean_http_kwargs` prunes falsy values (`0 == False`) from POST
   bodies: numeric-zero STATES are dropped entirely → HA 400 "No state
   specified". Always send states as `str(...)`. Fixed upstream by
   AppDaemon #2475 (first release after 4.5.13); keep `str()` until the
   add-on ships it. Attribute values of exactly 0/0.0/False are pruned too
   (cosmetic, known, not worked around).
3. `terminate()` cancel boilerplate is unnecessary: AD clears callbacks
   and timers automatically on app reload.

## maintenance_todo app (2026-09-20)

`apps/maintenance_todo/` creates todo items on `todo.tasks_todo` for: low
batteries (warn<=20 / crit<=15 / clear>=30, phones+tablet excluded), zigbee
offline (MQTT `home/zigbee2mqtt/+/availability`, 15min debounce, groups /
Coordinator / "901" skipped), ESPHome offline (`*_status` entities 10min, Z2M
bridge 5min), Jura alerts (2min), disk/memory thresholds, daily loud-log scan
(05:30, websocket get_error_log + SUPERVISOR_TOKEN), stale updates (7d).

Flap suppression: 3 offline events / 6h -> "Device flapping" item, suppressed
until 12h stable or item completed; state persisted in `flap_state.json`.
Dedup keys live in the item description; NEVER add when the todo list read
fails.

Add a detector: class in `detectors/` + registry entry in
`detectors/__init__.py` + config block under `detectors:` in `apps/apps.yaml`.
