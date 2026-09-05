---
name: offline-lab
description: "Orientation map for the offline-lab project: open tooling for offline/air-gapped computing on low-power ARM (Buildroot OS, putter, disco, esp32-timesyncd, boxctl). Use when working in /share/syncthing/projects/offline-lab, when a task mentions offline-lab/putter/disco/esp32-timesyncd/boxctl/bootconf, or before touching the OS image or its signed packages."
license: MIT
---

# offline-lab

Open tools for offline/air-gapped computing on low-power ARM devices. Two
halves: **Offline Lab OS** (minimal Buildroot Linux) and the **tooling**
(universal, not OS-specific). Each directory under the project root is its
own git repo. GitHub org: `offline-lab`.

Local checkout: `/share/syncthing/projects/offline-lab/`

## Layout

| Dir | What |
|-----|------|
| `putter/` | Go CLI — the CURRENT tool. Packages any Linux service into a small, immutable, signed disk image (DDI); runs via systemd portable services/nspawn, dm-verity, PKCS7. Replaces buildctl+appctl. |
| `old/buildctl/`, `old/appctl/` | Go — superseded by putter. Build signed DDI packages / install+manage them. Historical. |
| `framework/` | bash library + `boxctl` (device management CLI). Docs generator: `bin/generate-docs`. |
| `bootconf/` | boot configuration tool. |
| `disco/` | Go — local-network discovery daemon (custom NSS module for native Linux integration). |
| `esp32-timesyncd/` | ESP32 firmware: GPS stratum-1 NTP server + LoRa mesh repeater (MeshCore; Heltec Wireless Tracker). Stratum 1 with GPS fix, 2 in holdover, 16 unsynced. Broadcasts `TIME_ANNOUNCE` for disco. |
| `operating-system/`, `buildroot/` | the OS image itself. |
| `website/` | THE docs + decisions repo (`offline-lab/documentation`). |

## Where truth lives

- Rendered docs: `website/docs/` (specs in `website/docs/specs/`).
  Build/serve: `cd website && uv run bin/docs.py serve`.
- Decisions archive (ADRs, design notes, conversations, rejected
  approaches — NOT rendered to the site): `website/decisions/`.
- State files at the project root: `BACKLOG.md`, `TODO.md`,
  `OPEN-QUESTIONS.md`, and `BUILD-SESSION-HANDOVER.md` (current handover;
  `DESIGN-SESSION-HANDOVER.md` is historical).
- Each tool dir has its own `docs/` and usually a `CLAUDE.md`/`AGENTS.md` —
  read that FIRST when working in that tool.

## Key design principles

- DDI packages: signed, systemd-native verification, dm-verity, read-only
  rootfs, per-app user isolation, nftables.
- Offline-first, low-power, simple-over-clever. The tools are the product;
  the OS is just a (weird, read-only, wiped-`/etc`) customer.

## Working rules

- Never commit/push/amend without explicit user instruction.
- Buildroot package/defconfig/kernel conventions: see the `buildroot` skill
  (BR2_EXTERNAL tree, `.mk` variable prefixing, squashfs rootfs, KASLR).
- Patches to upstream buildroot never happen; everything lives in the
  BR2_EXTERNAL tree.
