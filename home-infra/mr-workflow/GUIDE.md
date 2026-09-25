<!-- source: flapperdeflipper, MIT -->
# Merge requests

MRs are GitHub PRs. They are created **only on explicit user request** —
AGENTS.md forbids unsolicited version control. Never push to `main`
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
2. Branch: `git fetch origin && git checkout -b <branch> origin/main`
   (unstaged changes carry over). Branch names follow repo precedent:
   `feature/<what>` / `fix/<what>` in addons, `add-<what>` in skills.
   **Every flapperdeflipper repo uses `main` (renamed from `master` on
   2026-09-25; old `master` links redirect).**
   For the **addons** repo, work in a worktree under `/data/worktrees/addons/`
   or `/share/worktrees` branched from `origin/main` — the main checkout
   may hold the human's in-flight branch.
3. Stage **only intended paths** — `git add <path> …`, never `git add -A` or
   `git commit -a`: the home-assistant-config checkout always carries many
   unrelated dirty files that must stay out.
4. `git commit -m "<message>"` (identity is configured).
   Message style: addons — `ha_opencode: bundle rsync (2.6.2)` i.e.
   `<addon>: <what> (<version>)`; skills — plain imperative subject.
5. `git push origin <branch>`
6. `gh pr create --repo flapperdeflipper/<repo> --base main --head <branch> \
   --title "<title>" --body "<description>"`
7. Report the PR URL and switch the checkout back to `main` (the changes
   live on the branch; local main catches up when the PR is merged —
   remind the user to merge **before** rebuilding an add-on or registering
   hub skills that point at main paths).

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

## Worktrees: one rule, all repos

NEVER work directly in a shared checkout (`/homeassistant/addons`,
`/homeassistant/skills`, `/share/syncthing/projects/*`) — multiple agents and
the human work there concurrently, and a `git add -A` in a shared tree has
already swept another agent's uncommitted WIP into a release once
(slopclanker 0.6.0). Every agent works in its own worktree, branched fresh
from `origin/main`, stage **explicit paths only**, and force-push own PR
branches only with `--force-with-lease=refs/heads/<branch>:<expected-sha>`
(URL pushes cannot resolve remote-tracking refs — plain `--force-with-lease`
fails with "stale info").

- Addons worktrees live in `/share/worktrees` (`addons`, `addons-2`, …) — see
  the map guide for add/remove/cleanup.
- Older `/data/worktrees/addons/<branch>` worktrees also exist; prefer
  `/share/worktrees`.
- `/homeassistant` (config repo) is the one exception: work on local `main`
  directly, but never `git add -A` there either — its working tree always
  carries unrelated dirty files.

**Before any push, verify the workdir**: run `git rev-parse --show-toplevel`
and check it is the worktree/repo you intend. On 2026-09-19 a push was run
with workdir `/homeassistant` instead of the addons worktree, pushing the
private config repo's HEAD to a public addons branch (deleted within minutes
via API; see the 2026-09-23 memory-value scratchpad report for the incident).

## Release pipeline quirks

1. Never create the GitHub release manually — the Release workflow **skips**
   if the tag's release already exists.
2. After a squash-merge, follow-up branches must rebase with
   `git rebase --onto origin/main <last-old-commit>`; never push during a
   conflicted rebase.
3. GitGuardian flags dummy username+password JSON pairs in tests — assemble
   fixture passwords instead of literal pairs.
4. GitHub pull_request CI events sometimes lag; merging on a green local gate
   is safe (main CI re-runs everything).
5. Addon base-image bumps are automated (since 2026-09-25): tag `vX.Y.Z` in
   agent-base -> CI builds/signs the image and publishes the GitHub release ->
   `update-addons.yml` opens a roll-up PR in addons (AGENT_BASE Dockerfile ARG,
   `build.yaml` `args` + `build_from`, patch version bumps, changelogs). Merge
   when green; update the branch first when a PR goes "out of date".
6. Supervisor store updates: `POST /store/reload` then
   `addons/{slug}/update`; the options body must be `{"options":{...}}`;
   partial backup = `POST /backups/new/partial`; supervisor error bodies can
   echo option values back — never send secret values there.
7. HA ingress: `ingress: true` without `ingress_port` assigns a dynamic port —
   declare it explicitly.
8. UI debugging: check ADDON LOGS first ("no request reached the server" is
   client-side); a pre-selected `<option>` fires no change event (empty-state
   create menus need placeholders); serve SPA index.html with
   `Cache-Control: no-cache`.

## Dependency automation

Dependabot (weekly, Mondays) was chosen over Renovate on 2026-09-05 for
`flapperdeflipper/{addons,skills,home-assistant-config}`; update PRs merge
manually — no automerge. Versioning: add-on versions are plain semver bumps
of our own line — never follow upstream versions, never `-N` suffixes. Rollup
merges of several Dependabot PRs are fine: combine on one branch, add version
bumps + CHANGELOG entries, squash-merge, close superseded PRs. Gotchas:
home-assistant/builder actions after 2026.02.1 reference unpublished builder
images (ignore rule lives in `addons/.github/dependabot.yml`); pushes to a PR
branch's dependabot files trigger a config-validating workflow; ARG-pins
(NODE_VERSION, BUILD_FROM, …) stay manual.
