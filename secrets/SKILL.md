---
name: secrets
description: Secret management policy and tooling for /homeassistant/secrets.yaml via hasecret — names-only discovery, masked output (*******), env-var injection instead of printing, byte-preserving writes, and op:// 1Password references. Use whenever a secret must be read, written, rotated, deleted, or consumed by a command; NEVER parse secrets.yaml with inline YAML/regex snippets.
license: MIT
metadata:
  author: flapperdeflipper
  version: 1.1.0
---

# Secrets

Everything lives in `/homeassistant/secrets.yaml` — one flat `key: value` per
secret, hand-maintained, grouped with comments. The tool is
`/homeassistant/bin/hasecret`; this file is the policy. Inline Python /
JavaScript / yq parsing snippets for secrets are **forbidden** — they leak
values into logs and pollute the context window with throwaway code.

## Hard rules

1. **Never print a secret.** Values are never echoed, logged, embedded in a
   response, committed, or written anywhere outside secrets.yaml and its
   hasecret-made backups. When a value or secret-derived string must be shown
   (confirming, debugging), mask it: `*******`. At most reveal shape:
   `len=43, url-safe`. No prefixes, no suffixes, no "just the first chars".
2. **Inject, don't read.** To use a secret in a command, inject it as an env
   var of the child process and expand it **inside a child shell**:
   `hasecret run KEY=litellm_master_key -- sh -c 'curl -H "Authorization: Bearer $KEY" …'`
   The value never reaches argv of the outer command, output, or logs.
   `hasecret get` is a last resort, only when the value itself is the
   deliverable (piping into another tool's stdin) — its output must never be
   quoted back into the conversation.
3. **Purpose-bound.** Every secret belongs to exactly one consumer, and the
   key name says which: `litellm_master_key` → the LiteLLM proxy,
   `deepseek_api_token` → DeepSeek, `prusa_api_key` → the printer. Never
   borrow a secret for a different tool, never "test" a credential against a
   service it doesn't belong to.
4. **Secrets never leave this world.** No POSTing, no query strings, no
   headers, no form fields to any endpoint outside this Home Assistant
   instance, its add-ons, and the LAN services named in secrets.yaml. Never
   paste a secret into web searches, GitHub issues/PRs, AI chat prompts,
   paste sites, or filenames. If an external service needs a credential, it
   gets its own secret created for that service — after explicit approval.
5. **Masked even when stale.** Rotated-away values, backup files, and error
   output that happens to contain secret fragments get the same `*******`
   treatment.

## Commands

| Command | What it does |
|---|---|
| `hasecret list` | key names only — the discovery view, safe to print |
| `hasecret get <key>` | prints one value (see rule 2 before using) |
| `hasecret set <key> [value or - for stdin]` | surgical write: one line changed, every other byte preserved; timestamped backup, verify-readback, atomic rename |
| `hasecret gen <key> [len=43]` | generate a random url-safe secret; prints only name + length |
| `hasecret delete <key>` | removes the key (backed up first) |
| `hasecret run NAME=KEY[,NAME2=KEY2] -- cmd` | runs cmd with secrets injected as env vars |
| `hasecret fingerprint` | sha256 of the file — change detection across sessions |
| `hasecret check` | parse validation + key count + empty-value report |
| `HASECRET_FILE=/tmp/x.yaml hasecret …` | operate on another file (tests, dry runs) |

Writes always: back up (`secrets.yaml.bak.<ts>`, gitignored, 10 kept) →
write to temp → validate parse → verify the key reads back exactly → atomic
rename. A failed verification aborts with the original untouched.

## `hasecret run` has NO shell

`run` execs its command directly (`exec env NAME=value cmd …`) — there is no
shell to expand `$NAME`:

- `hasecret run K=key -- curl -H "… $K"` → your own shell expands `$K` to
  **empty** before hasecret even runs;
- `hasecret run K=key -- curl -H '… $K'` → curl sends the **literal string**
  `$K`.

Always wrap the whole command in `sh -c` with single quotes so the injected
variable expands inside the child shell (rule 2 idiom). Multi-line works too:

    hasecret run KEY=litellm_master_key -- sh -c '
      curl -s -H "Authorization: Bearer $KEY" http://10.60.0.3:4000/v1/models
    '

## Idioms

Authenticated call against an internal service:

    hasecret run KEY=litellm_master_key -- sh -c \
      'curl -s -H "Authorization: Bearer $KEY" http://10.60.0.3:4000/v1/models'

Storing a value that already exists in a variable (never on the command line
of a shell history):

    printf '%s' "$TOKEN" | hasecret set github_token -

Rotating:

    hasecret gen paperless_api_key
    hasecret fingerprint   # before/after, to detect concurrent edits

Reporting any secret-derived value in a response: `*******` (rule 1).

## 1Password

Values may be 1Password references — store the reference, not the secret:

    hasecret set paperless_api_key 'op://Home-Infra/paperless/api-key'

`get` and `run` resolve `op://…` at read time through the 1Password CLI
(`op`, bundled with the opencode add-on ≥ 2.7.0). Auth is headless via a
service account: set `OP_SERVICE_ACCOUNT_TOKEN` in the add-on's **env_vars**
option (value `!secret op_service_account_token` resolves from secrets.yaml).
Direct `op` use is also fine — same masking rules apply:

    op read 'op://Home-Infra/paperless/api-key'   # think twice: prints — prefer hasecret run
    op item list --format json | jq '.[].title'   # inventory: titles only, never fields

Store in 1Password (via `op://` ref) when a secret is shared across machines
or needs rotation/audit; keep plain values for machine-local LAN plumbing.

## How consumers resolve secrets

- **Home Assistant config**: `password: !secret key` in any YAML.
- **litellm add-on**: options hold key *names* (`env_vars: [{name: X, secret: key}]`);
  values resolve from secrets.yaml at start. Same pattern works for any add-on.
- **opencode plugin** (`litellm-key.js`): calls `hasecret get litellm_ha_key`.
- **opencode memory MCP** (`bin/mcp-litellm-memory`): calls
  `hasecret get litellm_memory_key` at startup.

## Scope and boundaries

- This skill covers `/homeassistant/secrets.yaml` only.
- ESPHome secrets live in the ESPHome config dir — use the esphome MCP
  secrets tools, never this file.
- `.storage/`, `.cloud/`, `ssl/`, key/pem files: off limits entirely.
- secrets.yaml is gitignored; so are its `.bak.*` backups. Keep it that way.
