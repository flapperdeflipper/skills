---
name: bash-scripting
description: "Bash scripting conventions: strict mode, quoting, arrays, shellcheck, shfmt. Use when writing, editing, or reviewing shell scripts (.sh/.bash) or automation."
license: MIT
---

## Rules

- Shebang: `#!/usr/bin/env bash`
- Strict mode: `set -euo pipefail`
- Quote all variables. Use arrays for lists, not space-separated strings.
- POSIX-safe where possible; document when it isn't.
- Scripts must pass `shellcheck` (auto-checked on every edit).
- Format with `shfmt` (indent=4, binary-next-line), applied automatically on save.
- Non-obvious idioms get a one-line comment explaining why, not what.

## What I do

- Write robust, portable bash scripts
- Ensure shellcheck compliance
- Format with shfmt (indent=4, binary-next-line)
- Handle errors and edge cases properly
- Follow best practices for scripting

## When to use me

Use this skill when writing shell scripts, automation, or DevOps tooling.

## Best practices

1. **Shebang**: Use `#!/usr/bin/env bash` for portability
2. **Strict mode**: `set -euo pipefail`
3. **Quoting**: Always quote variables `"$var"`
4. **Arrays**: Use arrays for lists, not strings
5. **Functions**: Break logic into functions
6. **Error handling**: Check exit codes, use traps

## Shellcheck rules to follow

- SC2086: Double quote to prevent globbing
- SC2181: Check exit code directly
- SC2015: Note A && B || C is not if-then-else
- SC2034: Unused variables
- SC2155: Declare and assign separately

## Script template

```bash
#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
    # Implementation
}

main "$@"
```
