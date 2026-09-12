---
name: mqtt-mcp
description: "MQTT broker access for agents via the bundled mqtt MCP server (mqtt_publish, mqtt_listen, mqtt_clear_retained). Use when inspecting MQTT topics or retained state, watching live broker traffic, publishing messages, or cleaning up stale retained discovery - especially Home Assistant MQTT integrations, Zigbee2MQTT topics, and ESPHome raw-topic contracts."
license: MIT
metadata:
  author: flapperdeflipper
  version: 1.0.0
---

## The tools

Shipped by the ha_opencode add-on (2.10.0+, `/usr/local/bin/mcp-mqtt`, gated by
the **MCP integration** option; disabled in read-only sessions). They ride
Home Assistant's own MQTT connection through the Supervisor API - **no broker
credentials are involved**, so nothing to leak and no ACLs to fight.

| Tool | What it does |
|------|--------------|
| `mqtt_listen(topic, duration_seconds?)` | Subscribe and collect messages. **Retained messages arrive instantly**, so this is also how you read current broker state. Wildcards `#`/`+` allowed. |
| `mqtt_publish(topic, payload, retain?, qos?)` | Publish. Empty payload + `retain: true` clears one retained topic. |
| `mqtt_clear_retained(topics)` | Clear retained messages: one exact topic or a list. Enumerate first with `mqtt_listen`. |

`mqtt_listen` takes up to 60s; use short durations (2-5s) for retained-state
reads — the retained snapshot arrives immediately, the rest of the window only
collects live traffic.

## When to reach for this

- **Inspect retained state**: `mqtt_listen("homeassistant/#")` dumps discovery
  payloads (find stale duplicates, check `unique_id`s), `mqtt_listen("home/zigbee2mqtt/<device>")` shows a device's live JSON.
- **Stale MQTT discovery cleanup**: entities that stay in Home Assistant after
  a device was removed or renamed are almost always retained discovery
  messages. Enumerate, identify the exact `.../config` topics, clear them,
  done.
- **Raw-topic contracts**: ESPHome devices that use `mqtt:` with
  `discovery: false` (e.g. the alarm display fleet) are driven by plain topics
  like `home/alarm/display/<device>/set` — `mqtt_listen` to verify what the
  device publishes, `mqtt_publish` to command it.
- **Debugging "why did the automation fire"**: watch the topics an integration
  publishes while you toggle the thing.

## Safety

- `mqtt_publish` commands real devices. Confirm the topic and payload with the
  user before publishing to anything that actuates hardware or arms alarms.
- `mqtt_clear_retained` is a delete on the broker. Only clear topics you have
  just enumerated and can explain; never wildcard-clear — the tool takes exact
  topics by design.
- Never publish to `homeassistant/#` config topics to "fix" discovery — fix
  the announcing device instead, then clear the stale message.

## Interim wiring (pre-2.10.0)

Until the add-on release with the bundled server is merged/updated, the same
script runs from `/homeassistant/bin/mcp-mqtt`, wired via the add-on's
`opencode_config` option:

    "mqtt": { "type": "local", "command": ["node", "/homeassistant/bin/mcp-mqtt"],
              "enabled": true, "timeout": 65000 }

After updating the add-on, remove that entry — the generated base config wires
the in-image copy automatically (duplicate entries would race).

## Troubleshooting

- **"SUPERVISOR_TOKEN is not set"** — the server only runs inside the ha_opencode
  add-on; it cannot be spawned elsewhere.
- **`mqtt_listen` returns "no messages"** — either genuinely no traffic (check
  the topic filter spelling) or a retained-free topic: subscribe longer, or
  publish to it first.
- **Entity still in HA after clearing its discovery topic** — give Home
  Assistant a moment; if it lingers, the entity was created by a config entry
  (Zigbee2MQTT bridge, ESPHome native), not by that discovery message.
