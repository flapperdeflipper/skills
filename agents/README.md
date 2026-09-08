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
| `manager` | primary | Planning and delegation. Cannot edit or write. |
| `infra-engineer` | subagent | terraform, helm, kubernetes, cloud-architect |
| `code-engineer` | subagent | python, golang-pro, rust-engineer, typescript-pro, bash-scripting |
| `review-security` | subagent | code-review, security-reviewer. Read-only. |
| `debug-researcher` | subagent | systematic-debugging, diagnosing-bugs, research |
| `docs-writer` | subagent | documentation, writing-for-agents, writing-skills |
| `frontend-developer` | subagent | typescript-pro, playwright-expert, prototype |
| `dba` | subagent | postgres-pro |
| `senior-linux-engineer` | subagent | home-infra, sre-engineer, monitoring-expert, secrets |
| `embedded-linux-engineer` | subagent | buildroot, offline-lab |

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
    "terraform": allow
    "kubernetes": allow
```

A skill body loads when the skill fires. Bounding *which* skills an agent can
fire bounds what it can ever pull in. `dba` cannot load `kubernetes`; the
manager cannot load either. Allowlists are checked against real skill
directories in CI, so a renamed skill fails the build instead of silently
disappearing from an agent's reach.

**3. Reference routing inside skills.** Only `SKILL.md` loads when a skill
fires; anything in `references/` loads only when the SKILL.md points at it.
The heavy skills already work this way — `terraform` is 5k tokens of SKILL.md
in front of 43k of references, `kubernetes` 2k in front of 63k. Agents are
told to read the one reference file their task needs, not the tree.

For scale: all 57 skill descriptions together are ~3.2k tokens, and those are
resident in every session regardless. The bodies total ~380k. Which bodies
load is the entire game.

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
