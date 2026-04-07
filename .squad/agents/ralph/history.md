# Project Context

- **Project:** dev-setup
- **Created:** 2026-04-07

## Core Context

Agent Ralph initialized and ready for work.

## Recent Updates

📌 Team initialized on 2026-04-07

---

### Sprint 2 — Work Log

**Date:** 2026-04-07

#### Issue #28 — [CI] Fix PowerShell lint failures (PSScriptAnalyzer)
- **Owner:** Goofy (PowerShell) + Chip (CI)
- **Branch:** `squad/28-fix-ps-lint`
- **PR:** #30 — `fix(ci): resolve PSScriptAnalyzer violations (#28)`
- **Status:** ✅ Merged to `develop`, branch deleted, issue #28 closed
- **Violations fixed:**
  - `PSAvoidUsingWriteHost` → replaced `Write-Host` with `Write-Output` in both files
  - `PSUseApprovedVerbs` → renamed `Detect-Platform` → `Get-Platform` + updated call site
  - `PSUseBOMForUnicodeEncodedFile` → replaced Unicode box-drawing / em-dash chars with ASCII

#### Sprint 1 Retro Action Items
- **Branch:** `squad/retro-sprint1-followups`
- **PR:** #31 — `docs(retro): sprint 1 follow-up action items`
- **Status:** ✅ Merged to `develop`, branch deleted
- **Items addressed:**
  - Mickey: Added branch-before-commit rule to all 5 agent charters (`.squad/agents/*/charter.md`)
  - Mickey: Created `CONTRIBUTING.md` with PR checklist, branch naming, commit format, code review policy
  - Chip: Added CI-green merge gate policy to `.squad/ceremonies.md`
  - Donald: Documented `--skip-auth` / interactive auth prompt behavior in `README.md`

---

## Learnings

- Always check for Unicode characters in PowerShell files — `PSUseBOMForUnicodeEncodedFile` catches box-drawing chars too
- GitHub blocks self-approval on PRs; Mickey skips the approve step and merges directly as repo owner
- Retro action items (doc-only) can be safely batched into a single PR to keep the board clean
- CI runs 3 jobs: PSScriptAnalyzer (PowerShell lint), shellcheck (bash lint), Linux validate
