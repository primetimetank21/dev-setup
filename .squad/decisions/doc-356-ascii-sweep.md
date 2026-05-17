# Decision: Sprint 15 #356 ASCII sweep methodology + scope

**Date:** 2026-05-17  
**By:** Doc (Fact Checker)  
**What:** Sprint 15 legacy non-ASCII cleanup (#356) scope definition, file selection, and hand-conversion methodology for fenced code blocks.  
**Why:** Issue #356 identified 60+ pre-existing .md files with non-ASCII chars (em-dashes, smart quotes, box-drawing) that pre-date the #334 ASCII hook expansion. The hook only catches NEW additions; legacy debt required manual sweep. This decision documents scope, methodology, and file count for team reference.

## Scope

- **In scope:** All tracked .md files outside .squad/ (coordinator may handle separately)
  - 30 files: .copilot/skills/*.md
  - 3 files: ARCHITECTURE.md, tests/README.md, .github/agents/squad.agent.md
  - Total: 33 files, ~1,250 non-ASCII bytes removed

- **Explicitly out of scope:** 
  - .squad/ files (coordinator decision)
  - CHANGELOG.md (Mickey editing on #355 in parallel; merge conflict risk)
  - .yml workflow files (pre-existing em-dashes intentionally exempt per past decisions)

## Methodology

1. **Tool:** scripts/ascii-sweep.py (handles non-fenced content; preserves ``` ... ``` by design)
2. **Fence handling:** Manual replacement for non-ASCII inside code blocks using standard mapping table
3. **Mapping:** U+2500 (-) -> -, U+2502 (|) -> |, U+251C (|--) -> |--, U+2014 (--) -> --, U+2018/2019/2032/2033 (quotes) -> ', U+201C/201D/201E (double-quotes) -> ", U+2026 (...) -> ...
4. **Verification:** Python-based `ord(ch) > 127` check (Unicode character counting, not UTF-8 byte counting)
5. **Tool limitations noted:** PowerShell [System.IO.File]::WriteAllText may not persist changes reliably; Python pathlib preferred.

## Files cleaned  

Box-drawing trees (ARCHITECTURE.md), emoji/special chars (.copilot/skills/), test output templates (tests/README.md), agent roster (.github/agents/squad.agent.md).

## Residual count

0 files with remaining non-ASCII after cleanup. Pre-commit hook verification: PASS.

## Ship status

- PR #358 (squad/356-md-ascii-sweep off develop @ caf5c64)
- All staged, committed, pushed, PR created
- Ready for review
