# agents

opencode agent definitions. One manager that delegates, nine specialists that
do the work, each holding a narrow slice of tools and skills.

Format verified against the `AgentConfig` definition in
<https://opencode.ai/config.json> (opencode 1.18.27). Validated in CI by
`scripts/verify_skills.py` against `schema/agent-frontmatter.schema.json`.

## Install

opencode reads agents from `~/.config/opencode/agent/` (global) or
`.opencode/agent/` (per project). Symlink rather than copy, so a `git pull`
updates them:

```bash
mkdir -p ~/.config/opencode/agent
for f in /path/to/skills/agents/*.md; do
  [ "$(basename "$f")" = README.md ] && continue
  ln -sf "$f" ~/.config/opencode/agent/
done
```

Then `manager` is selectable as a primary agent, and the nine specialists are
reachable by `@name` or dispatched automatically via the `task` tool.

## The roster

| Agent | Mode | Owns |
|---|---|---|
| `manager` | primary | Planning and delegation. Cannot edit or write. dev-workflow, home-infra (mr-workflow) |
| `infra-engineer` | subagent | infrastructure |
| `code-engineer` | subagent | languages, backend |
| `review-security` | subagent | code-review, security-audit. Read-only. |
| `debug-researcher` | subagent | debugging, research |
| `docs-writer` | subagent | writing, software-design (domain-modeling) |
| `frontend-developer` | subagent | languages (typescript-pro), playwright-expert, software-design (prototype) |
| `dba` | subagent | backend (postgres-pro) |
| `senior-linux-engineer` | subagent | home-infra, operations, languages (bash-scripting), secrets, wizard |
| `embedded-linux-engineer` | subagent | offline-lab |

Most skills are hubs (see the top-level README), so an allowlist names a hub
and the agent's prompt names the guide inside it.

## How this bounds context

Three mechanisms, in descending order of effect.

**1. Subagent isolation.** A specialist runs in its own context window. The
files it reads and the output it churns through never enter the manager's
context — only its final report does. This is the large win, and it is why the
manager delegates even small edits.

**2. `permission.skill` allowlists.** Every agent denies `*` and allows only
the skills it owns:

```yaml
permission:
  skill:
    "*": deny
    "infrastructure": allow
    "secrets": allow
```

A skill body loads when the skill fires. Bounding *which* skills an agent can
fire bounds what it can ever pull in. `dba` cannot load `infrastructure`; the
manager cannot load it either. Allowlists are checked against real skill
directories in CI, so a renamed skill fails the build instead of silently
disappearing from an agent's reach.

Allowlists gate skills, not the files inside them, so a hub is the smallest
unit an allowlist can grant. An agent granted `backend` for `postgres-pro` can
also read the `mcp-developer` guide. That is acceptable because guides load
only when read, and each agent's prompt names the guides it should use.

**3. Routing inside skills.** Only a hub's `SKILL.md` router loads when the
skill fires. The router names one `GUIDE.md` for the task, and the guide names
at most one file under its `references/`. `infrastructure` → `terraform` is ~5k
tokens of guide in front of 43k of references; `kubernetes` is 2k in front of
63k. Agents are told to read the one guide and the one reference their task
needs, not the tree.

For scale: before the hub restructure, 56 model-visible descriptions came to
~3.2k tokens, resident in every session. Folded into hubs, 18 descriptions
come to ~1.3k (`verify_skills.py` prints the live number). The bodies total
~380k, and which of them load is still the whole game: a hub router costs
~500 tokens, and only the one guide it routes to loads after that.

## LiteLLM agent registry

`scripts/sync-agent-hub.sh` (repo root) mirrors this directory into the
LiteLLM A2A agent registry (`/v1/agents`): one agent card per `.md` file,
with the frontmatter description and the first `# ` heading as display
name. Cards carry `provider.organization: flapperdeflipper`; entries
without that marker are never updated or pruned. The server normalizes
cards (v1.100.0 rewrites `skills` to a default `chat` skill and fills
version/capabilities/security itself), so the sync manages only the
fields LiteLLM preserves — name, description, provider.

    scripts/sync-agent-hub.sh                  # dry run
    scripts/sync-agent-hub.sh --apply          # POST new, PUT changed
    scripts/sync-agent-hub.sh --apply --prune  # also delete removed agents

Run it from the HA box via `hasecret run KEY=litellm_master_key --` (or set
`LITELLM_MASTER_KEY` yourself). Re-run after adding an agent or changing a
description/allowlist — nothing propagates automatically.

**Cards are metadata only.** LiteLLM proxies A2A invocations to a live
server at the card's URL; no such server exists for these agents. Until one
does, registry entries are discovery/hub visibility — calling
`a2a/<agent-name>` against the gateway returns an error, not a specialist.
The opencode agents remain the real executors.

## Writing a new agent

- `description` is what the manager reads to decide what to delegate. Describe
  *when to use it*, not what the prompt says.
- Set `mode: subagent` unless it should drive a session directly.
- Deny by default in `permission`, then allow the specific commands and skills
  it needs. `bash: {"*": ask}` is a good baseline — unlisted commands prompt
  rather than fail.
- `tools:` is deprecated upstream. Use `permission:`.
- The markdown body is the system prompt. Give it real working rules, not a
  job title.
- Run `python3 scripts/verify_skills.py` before committing.
