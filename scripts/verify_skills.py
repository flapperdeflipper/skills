#!/usr/bin/env python3
"""Verify every skill and agent in this repository.

Checks, per top-level directory (excluding schema/, scripts/, agents/, .github/):
  - a SKILL.md exists
  - YAML frontmatter exists and parses into a mapping
  - frontmatter validates against schema/skill-frontmatter.schema.json
    (when the jsonschema package is importable; CI always has it)
  - name matches the directory name (the /command name comes from the dir)
  - description is 20-1536 chars; description + when_to_use <= 1536 combined
  - context budget: a model-invoked description stays <= DESC_BUDGET chars and
    SKILL.md <= SKILL_MD_BUDGET bytes (both are paid far more often than
    anything under references/ or a guide)
  - hub structure: no SKILL.md below the top level (a loader that globs
    recursively would list it as a separate skill again), and every
    <sub>/GUIDE.md is named as `<sub>` in the hub's SKILL.md router
  - every relative markdown link outside code fences resolves

Then, per agents/*.md (opencode agent definitions):
  - YAML frontmatter exists and parses into a mapping
  - frontmatter validates against schema/agent-frontmatter.schema.json
  - every skill named in permission.skill exists as a skill directory, so an
    allowlist cannot silently rot when a skill is renamed or removed

Exit code 0 only when every skill and agent passes. Run locally and in CI:

    python3 scripts/verify_skills.py
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SCHEMA_PATH = REPO_ROOT / "schema" / "skill-frontmatter.schema.json"
AGENT_SCHEMA_PATH = REPO_ROOT / "schema" / "agent-frontmatter.schema.json"
AGENTS_DIR = REPO_ROOT / "agents"
EXCLUDED_DIRS = {"schema", "scripts", "agents", ".github"}
NAME_PATTERN = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
DESC_MIN, DESC_MAX = 20, 1536
DESC_BUDGET = 400
SKILL_MD_BUDGET = 12_000
LINK_PATTERN = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")

try:
    import yaml
except ImportError:  # pragma: no cover
    yaml = None

try:
    import jsonschema
except ImportError:  # pragma: no cover
    jsonschema = None


def parse_frontmatter(path: Path) -> tuple[dict | None, str | None]:
    """Return (mapping, error). Frontmatter = first --- delimited block."""
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        return None, "file does not start with '---' frontmatter"
    parts = text.split("\n---\n", 1)
    if len(parts) < 2:
        return None, "frontmatter is not closed with '---'"
    block = parts[0][4:]
    if yaml is None:
        return None, "PyYAML not available"
    try:
        data = yaml.safe_load(block)
    except yaml.YAMLError as exc:
        return None, f"invalid YAML: {exc}"
    if not isinstance(data, dict):
        return None, "frontmatter is not a mapping"
    return data, None


def main() -> int:
    if yaml is None:
        print("error: PyYAML is required (pip install pyyaml)", file=sys.stderr)
        return 2

    schema = None
    if jsonschema is not None:
        schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    else:
        print("note: jsonschema not installed - schema validation skipped\n")

    failures = 0
    checked = 0
    description_chars = 0
    for entry in sorted(REPO_ROOT.iterdir()):
        if entry.name.startswith(".") or not entry.is_dir():
            continue
        if entry.name in EXCLUDED_DIRS:
            continue
        checked += 1
        problems: list[str] = []
        skill_md = entry / "SKILL.md"
        if not skill_md.is_file():
            print(f"FAIL {entry.name}: no SKILL.md")
            failures += 1
            continue

        fm, err = parse_frontmatter(skill_md)
        if err:
            print(f"FAIL {entry.name}: {err}")
            failures += 1
            continue

        if schema is not None:
            try:
                jsonschema.validate(fm, schema)
            except jsonschema.ValidationError as exc:
                problems.append(f"schema: {exc.message}")

        name = fm.get("name")
        if not name:
            problems.append("no name in frontmatter (directory name is used)")
        elif str(name) != entry.name:
            problems.append(f"name {name!r} != directory {entry.name!r}")
        if name and not NAME_PATTERN.match(str(name)):
            problems.append(f"name {name!r} fails kebab-case pattern")

        desc = fm.get("description")
        if not isinstance(desc, str) or not (DESC_MIN <= len(desc) <= DESC_MAX):
            problems.append(
                f"description must be {DESC_MIN}-{DESC_MAX} chars, got "
                f"{len(desc) if isinstance(desc, str) else 'non-string'}"
            )
        when = fm.get("when_to_use")
        if (
            isinstance(desc, str)
            and isinstance(when, str)
            and len(desc) + len(when) > DESC_MAX
        ):
            problems.append(f"description + when_to_use exceed {DESC_MAX} chars combined")

        if not fm.get("disable-model-invocation") and isinstance(desc, str):
            total = len(desc) + len(when) if isinstance(when, str) else len(desc)
            description_chars += total
            if total > DESC_BUDGET:
                problems.append(f"description is {total} chars, budget {DESC_BUDGET}")
        size = skill_md.stat().st_size
        if size > SKILL_MD_BUDGET:
            problems.append(
                f"SKILL.md is {size} bytes, budget {SKILL_MD_BUDGET}: move detail into a guide or references/"
            )
        if not entry.is_symlink():
            problems.extend(check_structure(entry, skill_md))

        if problems:
            print(f"FAIL {entry.name}: " + "; ".join(problems))
            failures += 1
        else:
            print(f"ok   {entry.name}")

    skill_names = {
        e.name
        for e in REPO_ROOT.iterdir()
        if e.is_dir() and not e.name.startswith(".") and (e / "SKILL.md").is_file()
    }
    agents_checked, agent_failures = verify_agents(skill_names)

    print(f"\n{checked} skills checked, {failures} failed")
    print(f"model-visible description budget in use: {description_chars} chars")
    print(f"{agents_checked} agents checked, {agent_failures} failed")
    if jsonschema is None:
        print("(run with jsonschema installed for full schema validation)")
    return 1 if (failures or agent_failures) else 0


def check_structure(skill_dir: Path, skill_md: Path) -> list[str]:
    """Hub layout and relative-link checks for one skill directory."""
    problems: list[str] = []
    router = skill_md.read_text(encoding="utf-8")
    for nested in sorted(skill_dir.rglob("SKILL.md")):
        if nested != skill_md:
            problems.append(f"nested {nested.relative_to(skill_dir)}: rename it GUIDE.md")
    for guide in sorted(skill_dir.glob("*/GUIDE.md")):
        sub = guide.parent.name
        if f"`{sub}`" not in router:
            problems.append(f"guide {sub}/GUIDE.md is not routed from SKILL.md")
    for doc in sorted(skill_dir.rglob("*.md")):
        in_fence = False
        for line in doc.read_text(encoding="utf-8").splitlines():
            if line.lstrip().startswith(("```", "~~~")):
                in_fence = not in_fence
                continue
            if in_fence:
                continue
            for target in LINK_PATTERN.findall(line.replace("`", "")):
                if re.match(r"^(?:[a-z]+:|#|<)", target):
                    continue
                path = target.split("#", 1)[0]
                if path and not (doc.parent / path).exists():
                    problems.append(f"broken link {doc.relative_to(skill_dir)} -> {target}")
    return problems


def verify_agents(skill_names: set[str]) -> tuple[int, int]:
    """Validate agents/*.md. Returns (checked, failures)."""
    if not AGENTS_DIR.is_dir():
        return 0, 0

    schema = None
    if jsonschema is not None:
        schema = json.loads(AGENT_SCHEMA_PATH.read_text(encoding="utf-8"))

    checked = failures = 0
    print()
    for path in sorted(AGENTS_DIR.glob("*.md")):
        if path.name == "README.md":
            continue
        checked += 1
        problems: list[str] = []

        fm, err = parse_frontmatter(path)
        if err:
            print(f"FAIL {path.name}: {err}")
            failures += 1
            continue

        if schema is not None:
            try:
                jsonschema.validate(fm, schema)
            except jsonschema.ValidationError as exc:
                problems.append(f"schema: {exc.message}")

        # An allowlist referencing a skill that no longer exists silently
        # widens or narrows the agent's reach, so treat it as a failure.
        allowed = (fm.get("permission") or {}).get("skill")
        if isinstance(allowed, dict):
            unknown = sorted(
                name
                for name in allowed
                if name != "*" and name not in skill_names
            )
            if unknown:
                problems.append(f"permission.skill names unknown skills: {', '.join(unknown)}")

        if problems:
            print(f"FAIL {path.name}: " + "; ".join(problems))
            failures += 1
        else:
            print(f"ok   {path.name}")

    return checked, failures


if __name__ == "__main__":
    sys.exit(main())
