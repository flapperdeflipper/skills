---
name: research
description: Investigate a question against primary sources and capture the findings as a Markdown file. Use when the user wants a topic researched, version or API facts confirmed, provider/CVE/upstream behaviour checked, or reading legwork delegated.
---

# Research

Adapted from [mattpocock/skills](https://github.com/mattpocock/skills).

Delegate the reading to a **background agent** so the user keeps working while it reads.

Its job:

1. Investigate the question against **primary sources**: official docs, release notes, changelogs, the actual source code, RFCs, provider schemas, first-party APIs. Not a blog post summarising them. Follow every claim back to the source that owns it.
2. Pin **versions**. A behaviour claim without the version, provider version or API version it applies to is not a finding. Note deprecations and removal timelines explicitly.
3. Write the findings to a single Markdown file, citing each claim's source URL inline.
4. Save it where the repo already keeps such notes. Match the existing convention. If there is none, use `~/.agents/scratchpad/` and say where.

State uncertainty as uncertainty. If the primary source does not answer the question, say so rather than filling the gap from memory.
