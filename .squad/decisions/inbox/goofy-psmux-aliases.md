# Decision: psmux aliases in Windows PowerShell profile

**Issue:** #140
**Agent:** Goofy (Cross-Platform Developer)
**Date:** 2025-07-17

## Context

The Linux/macOS setup defines tmux aliases (`tls`, `tks`, `tt`, `ta`) and a `create_tmux` function in `config/dotfiles/.aliases`. Windows had no equivalent.

## Decisions

### 1. Use psmux as the tmux equivalent
**Choice:** Map all tmux aliases to `psmux` commands instead of tmux.
**Why:** psmux is the Windows-native terminal multiplexer. The aliases mirror the Linux tmux workflow using the same short names (`tls`, `tks`, `tt`, `ta`).

### 2. Follow existing Invoke-* / Set-Alias pattern
**Choice:** Each alias gets a wrapper function (`Invoke-PsmuxList`, etc.) with a corresponding `Set-Alias`.
**Why:** Matches the established convention in the `$profileContent` heredoc for all other aliases (git, gh, dev shortcuts).

### 3. New-PsmuxSession as a named function (no alias)
**Choice:** `New-PsmuxSession` is called by name, not aliased.
**Why:** Mirrors `create_tmux` on Linux which is a function called directly. PowerShell verb-noun naming is idiomatic here.

### 4. Test group placed as Group I
**Choice:** Tests go in Group I (not Group F as originally specified in the issue).
**Why:** Groups F, G, and H were already taken by existing tests. Used next available letter.

## Outcome

Windows PowerShell profile now has full psmux alias parity with Linux tmux aliases.
