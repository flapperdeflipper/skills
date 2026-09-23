---
name: home-devices
description: "Physical devices and host-side services in this home: the TouchKio kiosk (bigtablet), Bluetooth LE room presence (Bermuda BLE proxy calibration), and the AppDaemon add-on (apps, MQTT/HA plugin quirks, maintenance-todo detector). Use for any work on these devices or their integrations."
license: MIT
metadata:
  author: flapperdeflipper
  version: 1.0.0
---

# Home devices

Router. Read only the guide the task needs: `<guide>/GUIDE.md` in this skill's
directory. Migrated from the retired LiteLLM memory store on 2026-09-23; when
a fact here goes stale, fix this file — it is the only home that fact has.

| Guide | Read when |
|---|---|
| `touchkio` | Anything about the bigtablet kiosk: SSH/service restart, Arguments.json, fullscreen gotcha, screen capture |
| `ble-presence` | Bermuda BLE room-presence work: scanners, RSSI offsets, calibration method, the stable-room sensor |
| `appdaemon` | AppDaemon apps in this install: MQTT/HA plugin quirks, supervisor REST patterns, the maintenance-todo app |
