<!-- migrated from LiteLLM memory 2026-09-23 (was opencode:homeassistant:ble-presence-calibration) -->
# BLE room presence (Bermuda)

Scanners: all 5 S3 displays (claude-livingroom-01, claude-sideroom-01/02,
clock-livingroom-01, clock-bedroom-01) + 3 WROOM proxies + hci0.

## Calibration (2026-09-17)

- Applied rssi_offsets via Bermuda options REST flow
  (`POST /api/config/config_entries/options/flow` — no WS command for this in
  HA 2026.9): clock-livingroom -15, hci0 -40, rest 0.
- Method: park the tweede phone (Tweede Phone BLE, IRK
  `flip_second_phone_irk_key`) at grid spots, read `bermuda.dump_devices`
  medians (hasecret curl to REST with `?return_response`).
- Result: 8.5h stable bedroom overnight (was 190 flips/night).

## The stable-room sensor

`sensor.ble_room_stable` in `entities/template/trigger/ble_room_stable.yaml`
(60s debounce). Needs the single `!include` in configuration.yaml —
trigger-based templates cannot go through the `template.sensor` dir_list.

## Gotchas

- Adding a Private BLE IRK needs a Bermuda reload before the device is tracked.
- The Bermuda options flow device field is `configured_devices` (single string,
  not a list).

## Pending (as of 2026-09-17)

Kitchen proxy replacement board; kitchen corner measurement; PadSpan
(github.com/gbroeckling/padspanHA) evaluation as a possible Bermuda successor.

Floor plan with 9 device markers + A-J/1-10 grid: `www/images/floorplan-bt.svg`
(cache-bust with `?v=N`).
