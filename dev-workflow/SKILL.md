---
name: dev-workflow
description: "Development lifecycle discipline: design before building (brainstorm, grill a plan), write and execute plans (inline, subagent-driven, parallel), git worktrees, TDD, verification before claiming done, finishing a branch, merge conflicts, pre-commit/deploy checklists. Use before any feature or bugfix work, and before claiming work complete."
---

# Dev workflow

Router. Read only the guide the task needs: `<guide>/GUIDE.md` in this skill's directory. Paths inside a guide are relative to that guide; when a guide says "use writing-plans" or "REQUIRED SUB-SKILL", it means the guide of that name here.

Always in force, guide or not:

- **No production code without a failing test first** (`test-driven-development`).
- **No completion claim without fresh verification evidence** run in this turn (`verification-before-completion`).
- **No building without an agreed design**: if none exists, `brainstorming`; if one exists but is untested, `grilling`.

| Guide | Read when |
|---|---|
| `brainstorming` | Creative work (feature, component, behavior change) with no agreed design yet |
| `grilling` | User has a plan or design and wants it stress-tested ("grill me", "poke holes") |
| `writing-plans` | A spec or requirements exist for a multi-step task, before touching code |
| `subagent-driven-development` | Executing a plan with independent tasks in this session (preferred when subagents exist) |
| `executing-plans` | Executing a written plan in a separate session, or without subagents |
| `dispatching-parallel-agents` | 2+ independent tasks with no shared state or ordering |
| `using-git-worktrees` | Feature work needing isolation from the current workspace, or before executing a plan |
| `test-driven-development` | Implementing any feature or bugfix, before implementation code |
| `verification-before-completion` | About to claim fixed/passing/done, commit, or open a PR |
| `finishing-a-development-branch` | Implementation done and tests pass; deciding how to integrate |
| `resolving-merge-conflicts` | A merge, rebase or cherry-pick stopped on conflicts |
| `workflow` | Pre-commit and pre-deploy checklists for Python, Terraform and Helm projects |

Reviews live in the `code-review` skill; debugging in `debugging`; PR mechanics on the flapperdeflipper repos in `home-infra` (`mr-workflow`).
