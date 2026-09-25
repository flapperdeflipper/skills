# skills

Personal agent skill collection, served through the LiteLLM skills gateway.

Mostly stolen from reddit and github, like anything LLM ;)

Each directory is a self-contained skill (`SKILL.md` with name/description
frontmatter). Consumed by Claude Code (marketplace), opencode, and any agent
that can read SKILL.md format.

`agents/` holds opencode agent definitions: one `manager` that plans and
delegates, plus nine specialists that each own a narrow set of tools and
skills. See [agents/README.md](agents/README.md) for installation and for how
the delegation and context model works.

- `schema/skill-frontmatter.schema.json` - skill frontmatter validation schema
- `schema/agent-frontmatter.schema.json` - agent frontmatter validation schema,
  mirroring opencode's `AgentConfig`
- `scripts/verify_skills.py` - validates every skill and agent locally (CI runs
  it too), including that each agent's `permission.skill` allowlist names
  skills that actually exist
- `scripts/sync-skill-hub.sh` - registers/updates skills in the LiteLLM hub
  (dry-run by default, `--apply` to execute); it globs `*/SKILL.md`, so
  `agents/` is not published as a skill
- CI (`verify-skills`) checks frontmatter against the schemas, the context
  budget and hub layout, shell script syntax and shellcheck, and runs the
  `security-audit` validator tests, on every PR and push to main
- Synced from local dotfiles; this repo is the canonical published source

## Keeping context small

Every model-invoked skill's `description` sits in context in every session, so
the repo keeps few of them. Related skills are folded into **hub skills**:

```
<hub>/SKILL.md            thin router: description + "read <guide> when" table
<hub>/<guide>/GUIDE.md    a former skill's body, loaded only when routed to
<hub>/<guide>/references/ deeper material, loaded only when the guide says so
```

| Hub | Guides |
|---|---|
| `dev-workflow` | brainstorming, grilling, writing-plans, executing-plans, subagent-driven-development, dispatching-parallel-agents, using-git-worktrees, test-driven-development, verification-before-completion, finishing-a-development-branch, resolving-merge-conflicts, workflow |
| `code-review` | branch-review, requesting-code-review, receiving-code-review |
| `debugging` | systematic-debugging, diagnosing-bugs |
| `software-design` | codebase-design, domain-modeling, prototype |
| `languages` | python, golang-pro, rust-engineer, typescript-pro, bash-scripting |
| `backend` | api-designer, fastapi-expert, postgres-pro, mcp-developer |
| `infrastructure` | terraform, helm, kubernetes, cloud-architect |
| `operations` | sre-engineer, monitoring-expert |
| `writing` | documentation, writing-for-agents, writing-skills, prompt-engineer |
| `home-infra` | map, home-assistant-ops, litellm-gateway, mqtt-mcp, opencode-sessions, session-cleanup, mr-workflow |
| `home-devices` | touchkio, ble-presence, appdaemon |
| `offline-lab` | project, buildroot |

Standalone skills: `security-audit` (vendored from
[cloudflare/security-audit-skill](https://github.com/cloudflare/security-audit-skill),
MIT; guidance mode by default, the six-phase audit lives in
`references/FULL-AUDIT.md`), `secrets`, `research`,
`socrates`, `playwright-expert`, `wizard`. `grill-with-docs`, `handoff` and
`improve-codebase-architecture` set `disable-model-invocation`, so they cost no
resident context and stay `/commands`.

Rules, enforced by `scripts/verify_skills.py`:

- Guides are named `GUIDE.md`, never `SKILL.md`: loaders that glob recursively
  would list them as separate skills again.
- Every guide is named in its hub's router table.
- A hub is self-contained (skills are installed one at a time); reach another
  hub's file by naming that skill, not with a `../../` path.
- Descriptions stay within 400 chars and `SKILL.md` within 12 KB. Put detail in
  a guide or `references/`.
- Relative markdown links must resolve.

Agents narrow this further: each one denies `skill: "*"` and allows only the
skills it owns, so a specialist can never pull in a domain it does not handle.
