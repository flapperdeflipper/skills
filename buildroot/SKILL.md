---
name: buildroot
description: Buildroot / Raspberry Pi (BR2_EXTERNAL) package, defconfig, and kernel conventions with security hardening. Use when writing or reviewing buildroot packages (.mk/Config.in), defconfigs, or kernel fragments.
license: MIT
---

## Buildroot / Raspberry Pi

Target boards: Pi Zero, Pi Zero 2W, Pi 3, Pi 4/CM4, Pi 5/CM5.
All customisations live in the BR2_EXTERNAL tree. Never modify upstream `buildroot/` directly.
Patches go via `BR2_GLOBAL_PATCH_DIR` or `board/<board>/patches/`.

### Package conventions (.mk)
- All variables use `PKGNAME_` prefix (uppercase).
- Use `$(INSTALL)` not `cp`. Use `$(eval $(cmake-package))` or appropriate closing macro.
- No `$(shell ...)` calls in .mk files.
- `PKGNAME_SITE` must use HTTPS. A `.hash` file with SHA256 is required for any fetched source.
- Pin versions to a tag or commit SHA, never a branch name.

### Config.in conventions
- `help` text on every option.
- `depends on` guards for optional features.
- `select` only for hard (unconditional) dependencies.

### Security defaults
- Never generate a defconfig with a blank root password.
- Prefer squashfs (read-only) rootfs over writable ext4. Flag writable root without an overlay strategy.
- Flag debug tools (`gdb`, `strace`, `telnetd`) in production defconfigs.
- Kernel fragments must include KASLR (`CONFIG_RANDOMIZE_BASE=y`) and stack protector at minimum.
