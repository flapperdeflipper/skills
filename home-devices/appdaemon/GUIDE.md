<!-- migrated from LiteLLM memory 2026-09-23 (was opencode:homeassistant:appdaemon_quirks + maintenance_todo_app) -->
# AppDaemon in this install

Add-on 0.19.2, AD 4.4.x. Apps live in
`/addon_configs/a0d7b954_appdaemon/apps/`.

## Plugin quirks (learned 2026-09-20)

1. MQTT events arrive as event name `MQTT_MESSAGE` in the plugin namespace,
   not `mqtt`. The plugin subscribes `client_topics` (default `["#"]`) at
   CONNECT time, so retained messages arrive BEFORE app listeners register —
   replay via `call_service("mqtt/subscribe", topic=...)` in a sweep.
2. `call_service` does NOT return service responses. Use REST via the
   Supervisor proxy: `POST http://supervisor/core/api/services/<domain>/<service>?return_response=true`
   with Bearer `SUPERVISOR_TOKEN` (response nests under
   `service_response.<entity_id>`). `get_error_log` is websocket-only.
3. App-level namespace in apps.yaml must be `default` for HA state; a per-app
   MQTT listener namespace must be passed separately (`plugin_namespace` key)
   to avoid variable collision.
4. `appdaemon.yaml` had dangling `!secret appdaemon_mqtt_*` refs that crashed
   AD on ANY restart — fixed 2026-09-20 by writing new secrets (host
   `172.30.32.1:1883`, user = Z2M's discovery `addons` user copied from
   `/share/zigbee2mqtt/configuration.yaml`). If mosquitto system-user passwords
   ever rotate, Z2M AND appdaemon both break until secrets are updated.

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
