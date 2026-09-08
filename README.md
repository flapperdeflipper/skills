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
- CI (`verify-skills`) checks frontmatter against the schemas, plus shell
  script syntax and shellcheck, on every PR and push to master
- Synced from local dotfiles; this repo is the canonical published source

## Keeping context small

Only a skill's `SKILL.md` loads when the skill fires; anything under
`references/` loads only when `SKILL.md` points at it. Heavy skills are built
that way deliberately — `terraform` is ~5k tokens of `SKILL.md` in front of
~43k of references, `kubernetes` ~2k in front of ~63k. When adding to a skill,
put reference material in `references/` and keep `SKILL.md` worth loading every
time.

Agents narrow this further: each one denies `skill: "*"` and allows only the
skills it owns, so a specialist can never pull in a domain it does not handle.
