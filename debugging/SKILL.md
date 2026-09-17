---
name: debugging
description: "Debugging discipline for any bug, test failure, flaky or intermittent behavior, or performance regression: root cause before any fix, and building a fast deterministic repro loop when none exists. Use before proposing a fix for anything broken or unexplained."
---

# Debugging

Router. Read only the guide the task needs: `<guide>/GUIDE.md` in this skill's directory. Paths inside a guide are relative to that guide.

Always in force: **no fixes without root-cause investigation first.**

| Guide | Read when |
|---|---|
| `systematic-debugging` | Default for any bug, test failure or unexpected behavior |
| `diagnosing-bugs` | The blocker is that there is no tight repro yet (flaky, intermittent, slow, only in a real environment). Build the loop first, then return to `systematic-debugging` |

Failing tests and completion claims follow `test-driven-development` and `verification-before-completion` in the `dev-workflow` skill.
