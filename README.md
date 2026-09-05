# skills

Personal agent skill collection, served through the LiteLLM skills gateway.

Mostly stolen from reddit and github, like anything LLM ;)

Each directory is a self-contained skill (`SKILL.md` with name/description
frontmatter). Consumed by Claude Code (marketplace), opencode, and any agent
that can read SKILL.md format.

- `schema/skill-frontmatter.schema.json` - frontmatter validation schema
- `scripts/verify_skills.py` - validates every skill locally (CI runs it too)
- `scripts/sync-skill-hub.sh` - registers/updates skills in the LiteLLM hub
  (dry-run by default, `--apply` to execute)
- CI (`verify-skills`) checks frontmatter against the schema, plus shell
  script syntax and shellcheck, on every PR and push to master
- Synced from local dotfiles; this repo is the canonical published source
