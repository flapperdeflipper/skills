<!-- migrated from LiteLLM memory 2026-09-23 (was opencode:homeassistant:touchkio-bigtablet) -->
# TouchKio kiosk "bigtablet"

HP Slate 17, 1920x1080, `10.20.1.250` / `bigtablet.home.lan`.

- SSH as `flip` with key `/homeassistant/.ssh/display` (sudo OK).
- App runs as user `kiosk` via systemd **user** unit `touchkio.service`. Restart:
  `sudo XDG_RUNTIME_DIR=/run/user/1001 systemctl --user -M kiosk@ restart touchkio.service`
- Config: `/home/kiosk/.config/touchkio/Arguments.json` — `web_url` is an
  **array** of pages (backup `.bak-opencode-20260920`). MQTT creds come from
  `/etc/default/kiosk`.
- GOTCHA (2026-09-20): after a service restart the window can come back
  "Maximized" (1640x814 floating) instead of Fullscreen, dashboard cut off at
  the top. Fix: `select.touchkio_bigtablet_kiosk = Fullscreen` (pin
  `app_kiosk: fullscreen` in Arguments.json).
- Screen capture: `sudo -u kiosk DISPLAY=:0 XAUTHORITY=/home/kiosk/.Xauthority scrot`
  (black image = display off via lights automation).
- Pages: 1) `http://10.20.0.3:8123` (HA) 2) `http://localhost:3000`
  (immich-kiosk.service) 3) `http://10.60.0.3:8126/home?skin=default`
  (AppDaemon HADashboard on the HA host; dashboard.pl4.dev redirects to
  auth.pl4.dev SSO, so use the local URL).
