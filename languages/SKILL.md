---
name: languages
description: "Language conventions and idioms for Python (typing, ruff/mypy), Go (concurrency, gRPC, generics), Rust (ownership, tokio, traits), TypeScript (advanced types, tRPC) and Bash (strict mode, quoting, shellcheck). Use when writing, editing, reviewing or debugging code in any of these languages."
---

# Languages

Router. Read only the guide for the language at hand: `<guide>/GUIDE.md` in this skill's directory. Each guide indexes its own `references/` (paths relative to the guide); read a reference only when the guide's table points to it for your task.

| Guide | Read when |
|---|---|
| `python` | `.py` files, libraries or scripts: typing, ruff/mypy, minimal deps, boundary validation |
| `golang-pro` | Go apps or CLIs: goroutines/channels, gRPC/REST, generics, interfaces, pprof, table tests |
| `rust-engineer` | Rust or Cargo: ownership, lifetimes, traits, tokio, error handling, FFI |
| `typescript-pro` | Demanding TS typing: generics, conditional/mapped/branded types, guards, monorepos, tRPC |
| `bash-scripting` | `.sh`/`.bash` scripts or automation: strict mode, quoting, arrays, shellcheck, shfmt |

Framework-level work (FastAPI, PostgreSQL, MCP servers) is in the `backend` skill.
