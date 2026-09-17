---
name: writing
description: "Writing for humans and for models: READMEs, API references, guides; agent-facing docs (skills, AGENTS.md, CLAUDE.md) and the test-first discipline for authoring skills; LLM prompts, structured outputs and eval suites. Use when the deliverable is documentation, a skill, or a prompt."
---

# Writing

Router. Read only the guide the task needs: `<guide>/GUIDE.md` in this skill's directory. Paths inside a guide are relative to that guide.

| Guide | Read when |
|---|---|
| `documentation` | README, API reference, guide, or explaining a complex system to humans |
| `writing-for-agents` | Prose conventions for skills, AGENTS.md or CLAUDE.md, including router skills (`SKILL-MECHANICS.md`) |
| `writing-skills` | Creating, editing or testing a skill before deploying it |
| `prompt-engineer` | Writing, refactoring or evaluating prompts, templates, structured-output schemas, eval rubrics |

In this repo a skill is a top-level directory with `SKILL.md`; most former skills are now guides under a hub like this one. Run `python3 scripts/verify_skills.py` after changes.
