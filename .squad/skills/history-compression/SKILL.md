---
name: history-compression
confidence: medium
applications: 3
last_updated: 2026-05-17
---

# history-compression

## When to use
Scribe applies this skill whenever an agent's `.squad/agents/{name}/history.md` approaches or exceeds the 15360 B (15KB) HARD GATE.

## Heuristic (4 steps)
1. **Front-matter verbatim** -- preserve agent identity / charter pointer / opening section.
2. **Current sprint verbatim** -- most recent sprint's "Learnings" entries kept at full fidelity.
3. **Older sessions to dated bullets** -- prior sprint entries compressed to one-line dated bullets (`- 2026-MM-DD: {one-line summary}`).
4. **Preserve skill triggers + recurring-incident refs** -- never lose pointers to formalized skills or "this happened again" signals.

## Target sizes
- Compress to **<13KB** to leave 2KB headroom for future appends.
- Hard gate at **15360 B** (15KB) -- pre-commit hook does NOT block, but Scribe folds re-compress before close.

## Rebound problem (recurring incident)
After Scribe compresses N files, subsequent agent hygiene-tail appends rebound files over gate. Solution: every fold MUST follow with a size-check + re-compress pass.

## Applications
1. **PR #319 / #332** -- Initial 8-agent history.md archival sweep
2. **PR #333 (Sprint 13 W1 fold)** -- jiminy/history.md re-compress (22548 -> 13078 B)
3. **PR #336 (Sprint 13 W2 fold)** -- Multi-file re-compress (jiminy, goofy, scribe, mickey)

## Validation
Pre-commit hook does NOT enforce the gate; Scribe's fold workflow does. Audit via:
`Get-ChildItem .squad\agents\*\history.md | ForEach-Object { "{0} {1}" -f $_.Length, $_.FullName }`
