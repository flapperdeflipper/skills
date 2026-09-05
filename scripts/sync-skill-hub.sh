#!/usr/bin/env bash
# Sync the skills repo (this repository) into the LiteLLM skills registry.
#
# The registry stores metadata only — consumers install skill content straight
# from git, so edits to a registered skill propagate without this script.
# What does NOT happen automatically: registering NEW skills, and updating
# hub metadata (description/version) after a change. This script does both.
#
# Endpoints (all need the master key):
#   GET    /claude-code/plugins            list
#   POST   /claude-code/plugins            register new
#   PUT    /claude-code/plugins/{name}     update existing
#   DELETE /claude-code/plugins/{name}     remove
#
# Dry-run by default; pass --apply to execute. Requires yq, jq, curl.
#
# Usage:
#   scripts/sync-skill-hub.sh                   show what would change
#   scripts/sync-skill-hub.sh --apply           register/update as needed
#   scripts/sync-skill-hub.sh --apply --prune   also delete registry entries
#                                               missing from the repo
#
# Overrides via environment:
#   LITELLM_URL         default https://llm.pl4.dev
#   LITELLM_MASTER_KEY  default: litellm_master_key from secrets.yaml
#   SECRETS_FILE        default /homeassistant/secrets.yaml
#   REPO_URL            git source recorded in the registry

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LITELLM_URL="${LITELLM_URL:-https://llm.pl4.dev}"
SECRETS_FILE="${SECRETS_FILE:-/homeassistant/secrets.yaml}"
REPO_URL="${REPO_URL:-https://github.com/flapperdeflipper/skills}"

APPLY=0 PRUNE=0
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=1 ;;
    --prune) PRUNE=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 1 ;;
  esac
done

if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -f "$SECRETS_FILE" ]; then
  LITELLM_MASTER_KEY=$(awk -F': *' '/^litellm_master_key:/ {gsub(/["'"'"']/, "", $2); print $2; exit}' "$SECRETS_FILE")
fi
if [ -z "${LITELLM_MASTER_KEY:-}" ]; then
  echo "error: no master key (set LITELLM_MASTER_KEY or point SECRETS_FILE at secrets.yaml)" >&2
  exit 1
fi

api() { # api METHOD PATH [JSON_BODY]
  local method=$1 path=$2 body=${3:-}
  if [ -n "$body" ]; then
    curl -sS -m 30 -X "$method" -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
      -H "Content-Type: application/json" -d "$body" "$LITELLM_URL$path"
  else
    curl -sS -m 30 -X "$method" -H "Authorization: Bearer $LITELLM_MASTER_KEY" "$LITELLM_URL$path"
  fi
}

registry_json=$(api GET /claude-code/plugins)
if ! existing=$(printf '%s' "$registry_json" | jq -c 'if has("plugins") then [.plugins[]] else [.[]] end | map({name, version, description})'); then
  echo "error: could not parse registry response:" >&2
  printf '%s\n' "$registry_json" | head -c 300 >&2
  exit 1
fi
if [ "$existing" = "[]" ]; then
  echo "error: registry list came back empty — refusing to run" >&2
  exit 1
fi

add=0 upd=0 unchanged=0 skipped=0 orphan=0

for skill_md in "$REPO_ROOT"/*/SKILL.md; do
  [ -f "$skill_md" ] || continue
  dir=$(basename "$(dirname "$skill_md")")
  fm=$(awk '/^---$/{n++; next} n==1{print} n>=2{exit}' "$skill_md")
  name=$(printf '%s\n' "$fm" | yq -r '.name // ""' -)
  desc=$(printf '%s\n' "$fm" | yq -r '.description // ""' -)
  version=$(printf '%s\n' "$fm" | yq -r '.version // ""' -)
  [ -z "$name" ] && name=$dir
  if [ -z "$desc" ]; then
    echo "SKIP  $dir: no description in frontmatter"
    skipped=$((skipped+1)); continue
  fi
  if [ "$name" != "$dir" ]; then
    echo "NOTE  $dir: frontmatter name '$name' differs from directory name"
  fi

  cur=$(printf '%s' "$existing" | jq -c --arg n "$name" '[.[] | select(.name == $n)][0]')
  body=$(jq -nc --arg n "$name" --arg d "$desc" --arg v "$version" \
    --arg url "$REPO_URL" --arg path "$dir" \
    '{name:$n, description:$d, source:{source:"git-subdir", url:$url, path:$path}} + (if $v=="" then {} else {version:$v} end)')

  if [ -z "$cur" ] || [ "$cur" = "null" ]; then
    echo "POST  $name (new)"
    if [ "$APPLY" = 1 ]; then
      api POST /claude-code/plugins "$body" | jq -r '"  -> " + (.status // .detail.error // tostring)' 2>/dev/null | head -c 200; echo
    fi
    add=$((add+1))
  elif printf '%s' "$cur" | jq -e --arg d "$desc" \
      '(.description // "") == $d' >/dev/null; then
    unchanged=$((unchanged+1))
  else
    echo "PUT   $name (description changed)"
    if [ "$APPLY" = 1 ]; then
      api PUT "/claude-code/plugins/$name" "$body" | jq -r '"  -> " + (.status // .detail.error // tostring)' 2>/dev/null | head -c 200; echo
    fi
    upd=$((upd+1))
  fi
done

for name in $(printf '%s' "$existing" | jq -r '.[].name'); do
  [ -f "$REPO_ROOT/$name/SKILL.md" ] && continue
  echo "ORPHAN $name (in registry, not in repo)"
  orphan=$((orphan+1))
  if [ "$APPLY" = 1 ] && [ "$PRUNE" = 1 ]; then
    api DELETE "/claude-code/plugins/$name" | head -c 120; echo
  fi
done

echo "---"
prune_hint=""
if [ "$PRUNE" = 0 ] && [ "$orphan" -gt 0 ]; then
  prune_hint=" (use --prune to remove)"
fi
echo "new: $add  updated: $upd  unchanged: $unchanged  skipped: $skipped  orphans: $orphan$prune_hint"
[ "$APPLY" = 0 ] && echo "dry run — pass --apply to execute"
