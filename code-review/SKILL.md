---
name: code-review
description: "Code review in both directions: review a branch, PR or WIP diff (Standards and Spec axes via parallel sub-agents), request a review from a subagent after finishing work, or handle review feedback you received with technical rigor. Use for reviewing, before merging, or when review comments arrive."
---

# Code review

Router. Read only the guide the task needs: `<guide>/GUIDE.md` in this skill's directory. Paths inside a guide are relative to that guide.

| Guide | Read when |
|---|---|
| `branch-review` | Performing a full review yourself of changes since a fixed point (commit, branch, merge-base) |
| `requesting-code-review` | Finished a task or major feature, or about to merge: dispatch a reviewer subagent so the diff stays out of your context |
| `receiving-code-review` | Feedback arrived: verify each point before implementing, push back when it is wrong |

Security vulnerabilities are a different job: use the `security-audit` skill.
