#!/usr/bin/env bash
# Vendor the upstream Dagu skill into dagu/.
#
# The skill is maintained in the Dagu repository itself (skills/dagu, shipped
# inside the dagu binary), so it follows the CLI release by release. Vendor the
# tag that matches the Dagu version running on hd and baked into agent-base, so
# the skill never documents flags the installed CLI does not have.
#
# The upstream files are copied verbatim. Local additions, re-applied on every
# run:
# - three frontmatter fields (license, metadata.source, metadata.ref) after the
#   description, recording where the copy came from;
# - references/house.md (this house's setup; maintained here, kept across
#   re-syncs) and a short "This house" section at the end of SKILL.md that
#   points to it.
#
# Usage:
#   scripts/vendor-dagu-skill.sh v2.17.2
#
# Requires curl and tar.

set -euo pipefail

REPO=dagucloud/dagu
REF=${1:?usage: scripts/vendor-dagu-skill.sh <tag, e.g. v2.17.2>}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEST="${ROOT}/dagu"

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT

curl -fsSL -o "${tmp}/src.tar.gz" "https://codeload.github.com/${REPO}/tar.gz/refs/tags/${REF}"
tar -xzf "${tmp}/src.tar.gz" -C "${tmp}" --strip-components=1
[[ -f "${tmp}/skills/dagu/SKILL.md" ]] || { echo "no skills/dagu/SKILL.md at ${REF}" >&2; exit 1; }

# Keep the locally maintained house reference across the re-sync.
HOUSE=references/house.md
if [[ -f "${DEST}/${HOUSE}" ]]; then cp "${DEST}/${HOUSE}" "${tmp}/house.md"; fi

rm -rf "${DEST}"
cp -R "${tmp}/skills/dagu" "${DEST}"
if [[ -f "${tmp}/house.md" ]]; then cp "${tmp}/house.md" "${DEST}/${HOUSE}"; fi
cp "${tmp}/LICENSE" "${DEST}/LICENSE"

# Insert provenance after the (single-line) description in the frontmatter.
awk -v src="https://github.com/${REPO}/tree/${REF}/skills/dagu" -v ref="${REF}" '
    NR == 1 && $0 == "---" { in_fm = 1; print; next }
    in_fm && $0 == "---" { in_fm = 0 }
    { print }
    in_fm && /^description: / && !done {
        print "license: GPL-3.0-or-later"
        print "metadata:"
        print "  source: " src
        print "  ref: " ref
        done = 1
    }
    END { if (!done) exit 1 }
' "${DEST}/SKILL.md" > "${tmp}/SKILL.md" || { echo "no description line in upstream frontmatter" >&2; exit 1; }
mv "${tmp}/SKILL.md" "${DEST}/SKILL.md"

if [[ -f "${DEST}/${HOUSE}" ]]; then
    cat >>"${DEST}/SKILL.md" <<'MD'

## This house

Working on this home's Dagu (automation-suite on hd: https://work.pl4.dev,
workers hd/ha/hb/hc)? Read `references/house.md` first: where DAGs live (git,
not the UI), how to validate locally, and how to run and inspect them through
the CLI context, MCP, REST or SSH. It overrides the generic advice above where
they differ.
MD
fi

echo "vendored ${REPO}@${REF} skills/dagu into dagu/"
echo "next: python3 scripts/verify_skills.py && git diff --stat -- dagu/"
