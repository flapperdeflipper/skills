---
name: resolving-merge-conflicts
description: Resolve an in-progress git merge or rebase conflict. Use when a merge, rebase or cherry-pick has stopped with conflicting files.
---

# Resolving Merge Conflicts

Adapted from [mattpocock/skills](https://github.com/mattpocock/skills).

1. **See the current state** of the merge or rebase. Check `git status`, `git log --oneline --graph` on both sides, and list the conflicting files.

2. **Find the primary source for each conflict.** Understand why each change was made and what the original intent was. Read the commit messages, the PR, the linked issue. Never resolve a hunk you do not understand.

3. **Resolve each hunk.** Preserve both intents where possible. Where they are incompatible, pick the one matching the merge's stated goal and note the trade-off. Do **not** invent new behaviour while resolving. Always resolve; never `--abort` without asking.

4. **Watch for silent merges.** Lockfiles, generated manifests and rendered output should be regenerated, not hand-merged. A textually clean merge of two valid YAML or HCL files can still be semantically wrong: re-render and diff.

5. **Discover the project's automated checks and run them.** Typically lint, typecheck or `terraform validate` / `helm lint`, then tests, then format. Fix anything the merge broke.

6. **Finish the merge or rebase.** Stage everything and hand back for commit. If rebasing, continue until all commits are replayed.

Committing is the user's call: `git commit`, `git push` and `git rebase --continue` are denied by policy here, so surface the exact command for them to run.
