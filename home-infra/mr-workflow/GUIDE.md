<!-- source: flapperdeflipper, MIT -->
# Merge requests

MRs are GitHub PRs. They are created **only on explicit user request** —
AGENTS.md forbids unsolicited version control. Never push to `master`
directly; always a feature branch + PR. Merging is the user's job unless they
explicitly ask otherwise.

## Tooling (since 2026-09-19: plain CLI, nothing to memorize)

`gh` is **permanently logged in** as `fliphess`. The token is stored by gh
itself in `/data/.config/gh/hosts.yml` (0600, persistent /data volume —
survives add-on restarts and updates). This is a user-approved exception to
the vault-only rule in the secrets skill, applying to `github_token` only.

All checkouts and worktrees share the persistent global gitconfig
(`/data/.gitconfig`): commit identity (fliphess), SSH→HTTPS rewrite
(`url.insteadOf`), and gh as credential helper (`gh auth setup-git`). So:

- `gh <anything>` — no prefix, no env vars
- `git push origin <branch>`, `git fetch`, `git pull` — just work
- `git commit -m "…"` — identity already configured

If `/data` is ever wiped, re-login is one command (note the `env -u`: gh
refuses to store a token while GH_TOKEN is in its own environment):

    hasecret run GH_TOKEN=github_token -- sh -c \
      'printf %s "$GH_TOKEN" | env -u GH_TOKEN gh auth login --with-token'
    gh auth setup-git

## Repos

| Repo | Checkout | Remote |
|---|---|---|
| addons | `/homeassistant/addons` | `git@github.com:flapperdeflipper/addons` (SSH) |
| skills | `/homeassistant/skills` | `https://github.com/flapperdeflipper/skills.git` |
| home-assistant-config | `/homeassistant` | `git@github.com:flapperdeflipper/home-assistant-config.git` |
| agent-base | `/homeassistant/agent-base` | `https://github.com/flapperdeflipper/agent-base.git` |

## Workflow

1. Confirm scope: which repo, which files, what the MR is for. If the working
   tree holds changes the user did not describe, list them and ask.
2. Branch: `git fetch origin && git checkout -b <branch> origin/master`
   (unstaged changes carry over). Branch names follow repo precedent:
   `feature/<what>` / `fix/<what>` in addons, `add-<what>` in skills.
   For the **addons** repo, work in a worktree under `/data/worktrees/addons/`
   or `/share/worktrees` branched from `origin/master` — the main checkout
   may hold the human's in-flight branch.
3. Stage **only intended paths** — `git add <path> …`, never `git add -A` or
   `git commit -a`: the home-assistant-config checkout always carries many
   unrelated dirty files that must stay out.
4. `git commit -m "<message>"` (identity is configured).
   Message style: addons — `ha_opencode: bundle rsync (2.6.2)` i.e.
   `<addon>: <what> (<version>)`; skills — plain imperative subject.
5. `git push origin <branch>`
6. `gh pr create --repo flapperdeflipper/<repo> --base master --head <branch> \
   --title "<title>" --body "<description>"`
7. Report the PR URL and switch the checkout back to `master` (the changes
   live on the branch; local master catches up when the PR is merged —
   remind the user to merge **before** rebuilding an add-on or registering
   hub skills that point at master paths).

## Hard rules

- Scan the staged diff for anything that looks like a secret VALUE before
  committing (tokens, keys, passwords) — mask as `*******` or drop the
  change. secrets.yaml and its `.bak.*` are gitignored; keep it that way.
- The stored token is never echoed, logged, pasted into PR bodies/issues,
  or put on a command line. References by NAME only.
- One MR per logical change.
- If a push is rejected (non-fast-forward, existing branch), stop and ask —
  never force-push.
- Known quirk: `gh pr edit` fails here (GraphQL "Projects (classic)" error) —
  use the REST API (`gh api repos/{owner}/{repo}/pulls/N -X PATCH …`).
