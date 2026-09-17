---
name: home-infra
description: "This home's infrastructure and agent stack: repo/add-on/endpoint map, the HA Supervised box and opencode add-on, LiteLLM MCP gateway, MQTT broker via the mqtt MCP tools (Z2M, ESPHome, retained state), past opencode sessions (lookup, cleanup), and PRs on flapperdeflipper repos. Use before changing add-ons or publishing anything, or for any of these."
---

# Home infra

Router. Read only the guide the task needs: `<guide>/GUIDE.md` in this skill's directory. Reading a secret for any of these goes through the `secrets` skill, never by parsing `secrets.yaml`.

| Guide | Read when |
|---|---|
| `map` | Before changing add-ons or publishing: which repo holds what, deployed add-ons, image builds, where secrets live, key endpoints |
| `home-assistant-ops` | Operating the Supervised install and its opencode/litellm stack: Supervisor API options, add-on config, skills hub publishing. Not HA YAML, dashboards or Zigbee/ESPHome |
| `litellm-gateway` | Wiring agents to MCP tools through the LiteLLM proxy, discovering or adding MCP servers |
| `mqtt-mcp` | Inspecting topics or retained state, watching traffic, publishing, clearing stale retained discovery (HA MQTT, Zigbee2MQTT, ESPHome) |
| `opencode-sessions` | Looking up what earlier opencode sessions did or decided; installing the sessions plugin |
| `session-cleanup` | Pruning finished or stale opencode sessions. Extract durable decisions first |
| `mr-workflow` | Any MR/PR on the flapperdeflipper repos (addons, skills, home-assistant-config): token-safe push, `gh pr create` |
