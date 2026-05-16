# Decision: Windows auth uses --web flag and is non-fatal

**Issue:** #191
**Author:** Donald (Shell Dev)
**Date:** 2026-05-16

## Context

Windows setup needed a gh auth step matching Linux parity. Two design
choices were made:

## Decisions

1. **Auth failure is non-fatal.** Invoke-GhAuth catches all errors and
   emits warnings. It never throws or exits non-zero. This matches the
   Linux auth.sh philosophy -- auth is optional quality-of-life, not a
   hard requirement for setup to succeed.

2. **Windows uses `--web` flag.** The `gh auth login` call uses
   `--hostname github.com --git-protocol https --web` to open the
   browser-based device flow. This avoids prompting the user for
   protocol/hostname interactively, reducing friction.

3. **Non-interactive detection.** Uses `$env:CI`, `$env:CODESPACES`,
   and `[Environment]::UserInteractive` to detect CI/headless runs.
   In those environments, auth is skipped with a warning.
