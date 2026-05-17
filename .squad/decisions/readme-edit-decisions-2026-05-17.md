# README Edit Decisions -- 2026-05-17 (Issue #342, Sprint 14 Wave 1.5)

**Author:** Mickey (Lead/Planner)
**Companion to:** `.squad/decisions/doc-readme-audit-2026-05-17.md` (Doc, 8 findings)
**Branch:** `squad/342-readme-edit` (off develop @ 234ee08)

This drop records the per-finding edit decisions applied to README.md in
response to Doc's fact-check audit. Captures what was changed verbatim,
what was deferred or skipped, and the load-bearing F3-first ordering so
the next "audit-then-edit" loop is mechanical.

## Decision Index

| Finding | Severity | Action | Implementation |
|---------|----------|--------|----------------|
| F1      | HIGH     | APPLIED | `### pre-commit` rewritten to 6-bullet list mirroring `hooks/pre-commit` header (Checks 1-6). Sprint 13 `.md`/`.sh` scope extension callout embedded in Check 2 along with `ascii-sweep.py` cross-reference. |
| F2      | HIGH     | APPLIED | New `### ASCII sweep helper (scripts/lib/ascii-sweep.py)` subsection at end of Git Hooks. Includes `--dry-run` usage + the fenced-code-preservation caveat. |
| F3      | HIGH     | APPLIED FIRST | File-tree fenced block at L80-L130 hand-converted from box-drawing glyphs (U+251C / U+2502 / U+2514 / U+2500) + em dashes (U+2014) to ASCII (`+--`, `|`, `\--`, `-`, `--`). 645 non-ASCII bytes -> 0. |
| F4      | MEDIUM   | APPLIED | `scripts/lib/ascii-sweep.py` line added under the `scripts/lib/` tree entry as the new `\--` last child. |
| F5      | MEDIUM   | APPLIED | `hooks/pre-commit` one-liner in the file-tree expanded from "Shellcheck on staged .sh files" to "6-check hygiene gate (branch ancestry + ASCII on .ps1/.md/.sh + .squad/ allow-list + inbox guard + branch refusal + shellcheck); see Git Hooks below". |
| F6      | LOW      | SKIPPED | Per-OS `lib/` subdirs (`scripts/linux/lib/`, `scripts/windows/lib/`) omitted from README tree. Defensible: README operates at coarser granularity than ARCHITECTURE.md, which already documents these (L41-L42, L55-L57). No reader confusion observed. |
| F7      | LOW      | FOLDED into F1 | The develop/main/master direct-commit refusal is Check 5 of the new 6-bullet `### pre-commit` description. No standalone bullet needed. |
| F8      | LOW      | EXPLICITLY SKIPPED | "team of nine specialized AI agents" left at "nine" per Doc's verified count against `.squad/team.md` (9 active rows) and `.squad/agents/` (9 dirs). Sprint 13 retro L9 confirms "nine agent dispatches". Task brief's "10 agents" did NOT match repo state; no 10th charter exists. If a 10th agent is hired, the L246 bump rides that PR. |

## Load-bearing F3-first ordering (skill candidate)

The audit flagged 645 non-ASCII bytes inside the README's file-tree fenced
code block. Two facts combine to make F3 the mandatory first step:

1. **`scripts/lib/ascii-sweep.py` (#322A) preserves fenced code by design.**
   See `sweep_text` in `scripts/lib/ascii-sweep.py` -- non-ASCII inside
   ``` ... ``` is left verbatim so code examples stay literal.
2. **`hooks/pre-commit` Check 2 (#322B / PR #334) does NOT respect fences.**
   It scans the full staged content via
   `git show ":$file" | grep -nP '[^\x00-\x7f]'`.

Therefore: running the sweep on README would have left the 645 bytes
intact, and staging README with those bytes still present would have
failed Check 2. Hand-conversion was the only path. Implementation:

```powershell
$text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
# Multi-char swaps first (preserve "+-- " / "\-- " idioms)
$text = $text.Replace([string][char]0x251C + [string][char]0x2500 + [string][char]0x2500, '+--')
$text = $text.Replace([string][char]0x2514 + [string][char]0x2500 + [string][char]0x2500, '\--')
# Then standalones
$text = $text.Replace([string][char]0x2502, '|')
$text = $text.Replace([string][char]0x2500, '-')
$text = $text.Replace([string][char]0x2014, '--')
# ...plus en-dash, smart quotes, nbsp, ellipsis
[System.IO.File]::WriteAllText($path, $text, [System.Text.Encoding]::ASCII)
```

**Skill candidate (2nd application if it recurs):** "audit-then-edit with
fenced-block precondition" -- when Doc audits a doc that contains fenced
non-ASCII, Mickey (or whoever applies) MUST hand-convert the fenced block
BEFORE any other edit lands, or `--no-verify` is the only path. Goofy's
sweep is necessary but insufficient for fenced content. Watch for the
3rd application before formalizing in `.squad/skills/`.

## Rejected alternatives

- **"Regenerate the file-tree from ARCHITECTURE.md's tree."** ARCHITECTURE.md
  uses a similar tree style; copying would risk introducing the same glyphs.
  Hand-conversion of the existing tree was lower-risk.
- **"Add F2 under `## Contributing` (Doc's alternative placement)."**
  Rejected: contributors hit the ASCII issue via pre-commit, not via
  Contributing. Putting the helper subsection adjacent to the
  `### pre-commit` description keeps the cross-reference one screen away.
- **"Add per-OS `lib/` subdirs (F6) for completeness."** Rejected as
  scope creep: README sits one level above ARCHITECTURE.md and the
  current tree is already at the deepest detail it should go. Promote
  to a follow-up issue only if a contributor reports confusion.

## Out-of-scope follow-ups (NOT addressed here)

- README's `hooks/` tree shows three entries (commit-msg, pre-commit,
  pre-push); the prose at L193 says "four hooks are active" and the
  fourth (`prepare-commit-msg`) has its own subsection at L216. The
  tree-vs-prose count mismatch is pre-existing and was NOT in Doc's
  audit (Doc verified "four hooks" prose as correct). File a separate
  issue if visible tree completeness matters.
- Sprint 13 ARCH/README accumulated other small staleness signals
  (e.g. `.gitattributes` not mentioned in README tree). Out of scope
  for #342; the next periodic Doc audit will surface them.

## Verification

- README.md: 11015 B -> 13039 B; 645 non-ASCII bytes -> 0.
- CHANGELOG.md: +1 bullet under `[Unreleased] ### Changed`.
- Pre-commit Checks 1-6 all green on the staged commit (verified before push).

## Confidence

HIGH on all 5 HIGH/MEDIUM applications (F1, F2, F3, F4, F5).
HIGH on F6/F7/F8 disposition (F8 verified by Doc against `.squad/team.md`;
F6/F7 explicit judgment recorded above).
