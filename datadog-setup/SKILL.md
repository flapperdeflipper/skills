---
name: datadog-setup
description: Install the Datadog pup CLI and the datadog-labs agent skill pack into a project. Use when Datadog work is needed on a machine that does not have pup or the dd-* skills yet.
---

# Datadog setup

The Datadog skill pack is not installed globally on purpose: 59 always-resident skill
descriptions cost context in every session, and Datadog work only happens on work
laptops. Install it per project instead.

## Install pup

```bash
brew tap datadog-labs/pack
brew install datadog-labs/pack/pup
pup auth login          # OAuth2 browser flow
pup auth status         # verify
```

## Install the skills

Install into the project, not `~/.claude/skills`, so the descriptions only load in repos
where Datadog is actually used:

```bash
cd <project-root>
npx skills add datadog-labs/agent-skills --skill dd-pup --full-depth -y
```

Add one `--skill <name>` per module needed. Pull the narrowest set that covers the task
rather than the full pack. Source: https://github.com/datadog-labs/agent-skills

Common modules: `dd-pup` (CLI reference, start here), `dd-logs`, `dd-monitors`, `dd-apm`,
`dd-docs`, `dd-symdb`, `dd-debugger`, `dd-unblock-pr`, `dd-triage-flaky-test`.

## Notes

- `dd-pup` is the base skill and the one worth installing first. Most other modules assume
  pup is authenticated.
- If `npx skills` is unavailable, copy the skill directory out of a clone of the repo into
  `.claude/skills/` directly.
- The full 59-skill pack was removed from this dotfiles repo. Recover any single skill's
  old content with:
  `git log --all --diff-filter=D --name-only -- 'profile/.agents/skills/dd-*'`
