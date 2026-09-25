#!/usr/bin/env bash
# Sync the agent definitions in agents/ into the LiteLLM A2A agent registry.
#
# Registry entries are agent cards (metadata) only: LiteLLM proxies A2A
# invocations to a live server URL, and no such server exists for these
# agents — entries exist for discovery/hub visibility until one does.
# LiteLLM normalizes cards server-side (v1.100.0 rewrites skills to a
# default "chat" skill and fills version/capabilities/security), so the
# sync manages only the fields it preserves: name, description, provider.
# Edits to an agent .md do NOT propagate automatically; this script
# registers new agents and updates changed cards.
#
# Endpoints (all need the master key):
#   GET    /v1/agents                list
#   POST   /v1/agents                register new
#   PUT    /v1/agents/{agent_id}     update existing
#   DELETE /v1/agents/{agent_id}     remove
#
# Cards written by this script carry provider.organization=flapperdeflipper;
# entries without that marker are never updated or pruned.
#
# Dry-run by default; pass --apply to execute. Requires yq, jq, curl.
#
# Usage:
#   scripts/sync-agent-hub.sh                   show what would change
#   scripts/sync-agent-hub.sh --apply           register/update as needed
#   scripts/sync-agent-hub.sh --apply --prune   also delete registry entries
#                                               missing from the repo
#
# Key via environment (preferred: hasecret run KEY=litellm_master_key -- ...):
#   LITELLM_MASTER_KEY  default: litellm_master_key from secrets.yaml
#   LITELLM_URL         default https://llm.pl4.dev
#   SECRETS_FILE        default /homeassistant/secrets.yaml
#   REPO_URL            git source recorded in the card provider

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENTS_DIR="$REPO_ROOT/agents"
LITELLM_URL="${LITELLM_URL:-https://llm.pl4.dev}"
SECRETS_FILE="${SECRETS_FILE:-/homeassistant/secrets.yaml}"
REPO_URL="${REPO_URL:-https://github.com/flapperdeflipper/skills}"
PROVIDER_ORG="flapperdeflipper"

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

registry_json=$(api GET /v1/agents)
if ! existing=$(printf '%s' "$registry_json" | jq -c \
    'if type == "array" then . else empty end
     | map({agent_id, agent_name, org: (.agent_card_params.provider.organization // "")})'); then
  echo "error: could not parse registry response:" >&2
  printf '%s\n' "$registry_json" | head -c 300 >&2
  exit 1
fi
if [ -z "${existing:-}" ]; then existing="[]"; fi

# frontmatter FILE -> folded frontmatter block on stdout
frontmatter() { awk '/^---$/{n++; next} n==1{print} n>=2{exit}' "$1"; }

# card JSON for an agent file: name (first H1, fallback stem) + description.
# skills are NOT sent: the server discards them (replaced by a default
# "chat" skill), so sending them would only break idempotency.
build_card() { # build_card FILE STEM -> card JSON on stdout
  local file=$1 stem=$2 fm
  fm=$(frontmatter "$file")
  local desc title
  desc=$(printf '%s\n' "$fm" | yq -r '.description // ""' -)
  title=$(awk '/^# /{sub(/^# +/, ""); print; exit}' "$file")
  [ -z "$title" ] && title=$stem

  jq -nc --arg n "$title" --arg d "$desc" \
    --arg org "$PROVIDER_ORG" --arg url "$REPO_URL" \
    '{protocolVersion: "1.0",
      name: $n,
      description: $d,
      defaultInputModes: ["text"],
      defaultOutputModes: ["text"],
      provider: {organization: $org, url: $url}}'
}

add=0 upd=0 unchanged=0 skipped=0 foreign=0 orphan=0

for agent_md in "$AGENTS_DIR"/*.md; do
  [ -f "$agent_md" ] || continue
  stem=$(basename "$agent_md" .md)
  [ "$stem" = "README" ] && continue
  desc=$(frontmatter "$agent_md" | yq -r '.description // ""' -)
  if [ -z "$desc" ]; then
    echo "SKIP  $stem: no description in frontmatter"
    skipped=$((skipped+1)); continue
  fi

  card=$(build_card "$agent_md" "$stem")
  cur=$(printf '%s' "$existing" | jq -c --arg n "$stem" '[.[] | select(.agent_name == $n)][0]')

  if [ -z "$cur" ] || [ "$cur" = "null" ]; then
    echo "POST  $stem (new)"
    if [ "$APPLY" = 1 ]; then
      body=$(jq -nc --arg n "$stem" --argjson c "$card" '{agent_name: $n, agent_card_params: $c}')
      api POST /v1/agents "$body" | jq -r '"  -> " + (.agent_id // .detail.error // .error.message // tostring)' 2>/dev/null | head -c 200; echo
    fi
    add=$((add+1))
  elif [ "$(printf '%s' "$cur" | jq -r '.org')" != "$PROVIDER_ORG" ]; then
    echo "FOREIGN $stem (exists without $PROVIDER_ORG marker — not touching)"
    foreign=$((foreign+1))
  elif [ "$(printf '%s' "$card" | jq -r '.name')" = "$(api GET "/v1/agents/$(printf '%s' "$cur" | jq -r '.agent_id')" | jq -r '.agent_card_params.name // ""' 2>/dev/null)" ] && \
       [ "$(printf '%s' "$card" | jq -r '.description')" = "$(api GET "/v1/agents/$(printf '%s' "$cur" | jq -r '.agent_id')" | jq -r '.agent_card_params.description // ""' 2>/dev/null)" ]; then
    unchanged=$((unchanged+1))
  else
    echo "PUT   $stem (card changed)"
    if [ "$APPLY" = 1 ]; then
      body=$(jq -nc --arg n "$stem" --argjson c "$card" '{agent_name: $n, agent_card_params: $c}')
      api PUT "/v1/agents/$(printf '%s' "$cur" | jq -r '.agent_id')" "$body" | jq -r '"  -> " + (.agent_id // .detail.error // .error.message // tostring)' 2>/dev/null | head -c 200; echo
    fi
    upd=$((upd+1))
  fi
done

repo_stems=$(cd "$AGENTS_DIR" && for f in *.md; do [ "$f" = "README.md" ] || basename "$f" .md; done)
for entry in $(printf '%s' "$existing" | jq -c '.[]'); do
  name=$(printf '%s' "$entry" | jq -r '.agent_name')
  id=$(printf '%s' "$entry" | jq -r '.agent_id')
  org=$(printf '%s' "$entry" | jq -r '.org')
  case "
$repo_stems
" in *"
$name
"*) continue ;; esac
  if [ "$org" != "$PROVIDER_ORG" ]; then
    echo "ORPHAN $name (foreign, never pruned)"
    orphan=$((orphan+1)); continue
  fi
  echo "ORPHAN $name (in registry, not in repo)"
  orphan=$((orphan+1))
  if [ "$APPLY" = 1 ] && [ "$PRUNE" = 1 ]; then
    api DELETE "/v1/agents/$id" | head -c 120; echo
  fi
done

echo "---"
prune_hint=""
if [ "$PRUNE" = 0 ] && [ "$orphan" -gt 0 ]; then
  prune_hint=" (use --prune to remove ours)"
fi
echo "new: $add  updated: $upd  unchanged: $unchanged  skipped: $skipped  foreign: $foreign  orphans: $orphan$prune_hint"
[ "$APPLY" = 0 ] && echo "dry run — pass --apply to execute"
