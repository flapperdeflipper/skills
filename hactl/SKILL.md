---
name: hactl
description: "Home Assistant control from the CLI via hactl (hemm-ems/hactl), bundled in the ha_opencode add-on 2.12.0+. Use for multi-step HA diagnosis (failing automations, traces, entity anomaly/actor history, config reference scans), reading/writing HA config with dry-run + --confirm, real-engine template evaluation, and multi-instance operation. Output is token-capped for LLM context budgets."
license: MIT
metadata:
  author: flapperdeflipper
  version: 1.0.0
---

## What this is

`hactl` ships in the ha_opencode add-on (2.12.0+, `/usr/local/bin/hactl`). It
talks to Home Assistant's REST/WebSocket API from the shell, with output
capped for LLM context budgets. One directory = one HA instance.

## Wiring on this add-on

- `HACTL_DIR=/data/hactl` is already exported in every session.
- The init service writes `/data/hactl/.env` (chmod 600) with the add-on's
  `access_token` option (an owner long-lived token — exactly what companion
  discovery needs) and `HA_URL` pointing at **HA Core's real origin** (the
  host gateway, probe-verified at add-on start). The Supervisor `/core` proxy
  is deliberately not used: it rejects the long-lived token and breaks hactl's
  WebSocket auth. If `.env` is missing, the token option is unset — the shell
  wrapper prints setup steps.
- `hactl companion status` checks the hactl-companion add-on (installed from
  the external repo `https://github.com/hemm-ems/hactl-companion`), which
  unlocks create/update/delete of things the HA API does not expose
  (template entities, helpers, config blocks).

## First rule

Run `hactl rtfm` before first use in a session (it is uncapped). In agent
harnesses hactl also injects the manual progressively on stderr — core first,
then per-family sections — so the manual arrives on its own; `rtfm` forces it.
`HACTL_MANUAL_MODE=off` disables injection. Never invent commands or flags:
the manual's command list is exhaustive; unclear flags → `<command> --help`.

## Token budget

Output caps at ~500 tokens by default. `--tokens` prints per-command
estimates, `--tokensmax=N` raises the cap (`0` = uncapped). Raise it
deliberately — a single uncapped `log` can blow the context.

## Write discipline (matches the AGENTS.md consent rules)

- Config writes (`auto`/`script`/`helper`/`tpl`/`dash` create/apply/delete,
  `config` changes) are **dry-run by default**: hactl prints a diff and
  validates via HA's own `validate_config`, with automatic backup. Only
  `--confirm` writes. Never pass `--confirm` without explicit user approval
  of the shown diff. `hactl auto rollback` undoes automation applies.
- `svc call` and `script run` execute **immediately** — treat them like
  `call_service`: confirm target and intent first.
- Templates are evaluated by HA's real Jinja engine (`tpl eval`), not a mock.

## Routing on this install

| Need | Use |
|---|---|
| Single live value, service call, history slice | MCP `homeassistant` tools |
| "What broke?" sweep: health, unique error log, recent changes | `hactl health` → `hactl log --errors --warnings --unique` → `hactl changes --since 24h` |
| Which automation failed, why | `hactl auto ls --failing` → `auto show <id>` → `trace show <trc:XX>` |
| Sensor behaving oddly | `hactl ent anomalies <id>` → `ent hist <id> --since 7d` |
| What controls an entity | `hactl ent who <id>` (actor history) + `ref scan <id>` (config/dashboard references) |
| Config file edits with diff + validation | hactl dry-run + `--confirm` (companion) or `write_config_safe` (MCP) |
| Dashboards, areas, helpers, blueprints via CLI | `hab` |
| Entity/device renames with cascade | `zigporter` (hactl does not cascade references) |

`ref replace` edits references but does not cascade renames — renames stay
zigporter's job. Multi-instance: create another dir with its own `.env` and
point at it with `--dir`/`HACTL_DIR`.
