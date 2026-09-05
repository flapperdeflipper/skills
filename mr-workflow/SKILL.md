---
name: mr-workflow
description: "Create merge requests (GitHub PRs) on the flapperdeflipper repos (addons, skills, home-assistant-config) via the github_token secret and hasecret env injection: branches, scoped staging, token-safe push, gh pr create. Use when an MR/PR is requested."
license: MIT
metadata:
  author: flapperdeflipper
  version: 1.0.0
---

# Merge requests

MRs are GitHub PRs. They are created **only on explicit user request** —
AGENTS.md forbids unsolicited version control. Never push to `master`
directly; always a feature branch + PR. Merging is the user's job unless they
explicitly ask otherwise.

## Repos

| Repo | Checkout | Remote |
|---|---|---|
| addons | `/homeassistant/addons` | `git@github.com:flapperdeflipper/addons` (SSH) |
| skills | `/homeassistant/skills` | `https://github.com/flapperdeflipper/skills.git` |
| home-assistant-config | `/homeassistant` | `git@github.com:flapperdeflipper/home-assistant-config.git` |

The GitHub account behind the `github_token` secret is `fliphess`; the
username secret is `github_username`.

## Auth — the token never leaks

`gh` is not logged in; drive it per-command with GH_TOKEN injected by
hasecret (env only — never argv, files, or `.git/config`):

    hasecret run GH_TOKEN=github_token -- gh pr create ...

Pushes use a one-shot credential helper. Nothing is persisted, the token
never appears in a remote URL or process listing:

    hasecret run GH_TOKEN=github_token -- git \
      -c credential.helper='!f() { echo username=x-access-token; echo password=$GH_TOKEN; }; f' \
      push https://github.com/flapperdeflipper/<repo>.git HEAD:refs/heads/<branch>

SSH remotes are for the human; scripted pushes always go via HTTPS + helper.

## Workflow

1. Confirm scope: which repo, which files, what the MR is for. If the working
   tree holds changes the user did not describe, list them and ask.
2. Branch: `git fetch origin && git checkout -b <branch> origin/master`
   (unstaged changes carry over). Branch names follow repo precedent:
   `feature/<what>` / `fix/<what>` in addons, `add-<what>` in skills.
3. Stage **only intended paths** — `git add <path> …`, never `git add -A` or
   `git commit -a`: the home-assistant-config checkout always carries many
   unrelated dirty files that must stay out.
4. Commit with an explicit identity (no global git config in this container):

       git -c user.name=fliphess \
           -c user.email=fliphess@users.noreply.github.com \
           commit -m "<message>"

   Message style: addons — `ha_opencode: bundle rsync (2.6.2)` i.e.
   `<addon>: <what> (<version>)`; skills — plain imperative subject.
5. Push the branch (helper above), then:

       hasecret run GH_TOKEN=github_token -- gh pr create \
         --repo flapperdeflipper/<repo> --base master --head <branch> \
         --title "<title>" --body "<description>"

6. Report the PR URL and switch the checkout back to `master` (the changes
   live on the branch; local master catches up when the PR is merged —
   remind the user to merge **before** rebuilding an add-on or registering
   hub skills that point at master paths).

## Hard rules

- Scan the staged diff for anything that looks like a secret VALUE before
  committing (tokens, keys, passwords) — mask as `*******` or drop the
  change. secrets.yaml and its `.bak.*` are gitignored; keep it that way.
- The token flows only through `hasecret run` / env — never echoed, logged,
  or written to any file, remote URL, or PR body.
- One MR per logical change.
- If a push is rejected (non-fast-forward, existing branch), stop and ask —
  never force-push.
- PR bodies may reference secrets by NAME only.
