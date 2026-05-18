# Donald History Archive

> Archived 2026-05-18 by Jiminy (S17 audit). Pre-Sprint-12 entries moved here to keep history.md under 15360-byte gate.

---

## Recent Work (pre-Sprint-9 summary)

Compressed; full detail dropped in favor of preserved lessons in Learnings.

- **2026-04-12 to 2026-04-13** Issues #68/#69 stdout/stderr merge + CRLF guard (PR #70/#71 merged). Issue #72 directory-based install check + printf pipe (PR #73 merged). Issues #75/#76 vim prerequisites + script PTY for Copilot CLI (PRs #77/#78). Issue #76 revised: standalone copilot-cli install via official script (PR #82).
- **2026-04-12 -- Issue #79 / PR #80** CI=true env var to bypass non-interactive Copilot binary download (isatty()/IsCI gate fix). Root cause traced in cli/cli source.
- **2026-04-13 to 2026-04-25** PR #146 test regressions fixed (Issue #138), PR #170 Remove-Item AllScope guard for `ep` alias.
- **2026-04-19** Issue #138 lead session wrap-up (dual-path profile + force-alias).
- **2026-05-04** Issue #173 / PR #176 shell aliases for shutdown control. Post-sprint Linux shell audit (2026-05-16).

Lessons preserved verbatim in Learnings section of history.md (gh built-in `--` passthrough, CI=true non-interactive trigger, exec 2>&1 for ordered output, CRLF onCreateCommand guard, directory check over exit-code probe).

---

## Learnings

### 2026-04-19: Issue #178 -- macOS/Linux install_prerequisites divergence

The `install_prerequisites()` function in `scripts/linux/setup.sh` maintains separate package lists
for macOS (brew) and Linux (apt). These lists can silently drift apart -- vim was present in the
Linux apt path but missing from the macOS brew path. When adding new prerequisites, always verify
both platform branches get the package to maintain the cross-platform parity documented in README.
**PRs:** #70, #71
**Status:** [x] Both merged to develop

**Issue #68 -- exec 2>&1 for ordered log output:**
- Root cause: stderr and stdout buffers independent in piped environments; error lines appear before unrelated INFO/OK lines
- Fix: `exec 2>&1` immediately after `set -euo pipefail` in setup.sh and scripts/linux/setup.sh
- Rule: FD inheritance covers all child processes; no need to add to tool scripts

**Issue #69 -- onCreateCommand CRLF guard in devcontainer:**
- Root cause: PR #66 added `.gitattributes` eol=lf + `git add --renormalize`, but this updates git INDEX only, not working tree
- Windows users with existing checkout still have CRLF .sh files; bind-mount sees `set: pipefail\r` errors
- Fix: `onCreateCommand` strips `\r` before `postCreateCommand` runs
- Rule: When adding .gitattributes eol rules, always add devcontainer onCreateCommand CRLF strip as defensive guard

### Issue #189 - Uninstall/cleanup scripts (2025-07-17)

- Created scripts/linux/uninstall.sh and scripts/windows/uninstall.ps1
- Linux markers: # --- dev-setup managed block (do not edit) --- / # --- end dev-setup managed block ---
- Windows markers: # BEGIN dev-setup profile / # END dev-setup profile
- Dotfile .bak paths: ~/.gitconfig, ~/.npmrc, ~/.editorconfig, ~/.aliases, ~/.vimrc
- Windows profile paths: Documents/WindowsPowerShell and Documents/PowerShell
- Uninstallers are idempotent; tools intentionally left installed
- PS1 ASCII safety: box-drawing chars (U+2500 range) trigger the same CP1252 issue as em dashes

### Issue #191 - Windows GitHub auth step (2026-05-16)
- PR: TBD -- `feat(windows): add gh auth step`
- Branch: `squad/191-windows-auth` from `develop`
- What: Added scripts/windows/auth.ps1 with Invoke-GhAuth that mirrors Linux auth.sh
- Key findings: Linux uses gh auth login with no flags; Windows uses --hostname github.com --git-protocol https --web for explicit interactive flow. Auth failure is always non-fatal (warn and continue). Non-interactive detection via CI/CODESPACES env vars and [Environment]::UserInteractive.
- Tests: Group S verifies function exists (S-1), exits cleanly when gh missing (S-2), skips prompt when already authenticated (S-3)

### Audit verification (2026-05-04)
- **Task:** Verify 5 findings from gap-audit (V-2, V-4, V-10, V-12, V-14)
- **Report:** .squad/agents/donald/verification-report-2026-05-04.md
- **Summary:** V-2 CONFIRMED (logging consolidation, P1); V-4 CONFIRMED (macOS Homebrew guidance, P2); V-10 CONFIRMED but P3 (POSIX syntax in .aliases, not needed); V-12 CONFIRMED but needs design decision on squad-cli versioning; V-14 CONFIRMED but intentional in some tests (test harness pattern).
- **Hits:** Real issues in logging duplication and test inconsistency.
- **Misses:** V-10 and V-14 are design choices, not bugs. V-12 requires squad-cli versioning philosophy decision.

- **2026-05-16 -- Cleanup of rogue verification reports.** Coordinator dropped Scribe between verifier batch and Mickey filing, so verifier history edits + 3 rogue VERIFICATION_REPORT files sat uncommitted on develop. I consolidated all 3 reports into .squad/orchestration-log/2026-05-16-verification-evidence.md (correct location per Source of Truth Hierarchy), deleted the rogues, and committed everything. Lesson: rogue files at .squad/{anything-not-in-spec}.md are spawn-hygiene violations. Future verifier batches must use ONE of: history.md (learnings), decisions/inbox/ (decisions), orchestration-log/ (evidence).
- 2026-05-16: Jiminy joined the squad as Hygiene Auditor (process QA, not code review). Will audit your hygiene compliance after spawns. See .squad/agents/jiminy/charter.md for scope.
- 2026-05-16 Hygiene retro complete -- 4 action items shipped (pre-spawn-checklist skill + squad-history-check CI gate + PR template + 6 standing rules). See .squad/log/2026-05-16-hygiene-retro-complete.md.

- **2026-05-16 -- Reviewed PR #244 (Mickey's retroactive tags + 0.8.0 cut).** Verdict: APPROVE (posted as comment since GitHub single-owner repos cannot self-approve; --admin merge used). CHANGELOG cut is clean (empty Unreleased, all entries under 0.8.0, no drops). Spot-checked 3/7 SHAs (0.1.0, 0.5.0, 0.7.0) -- all point at release-shaped merge commits matching Mickey's rationale table. All 7 tags and GitHub releases confirmed present. Commit uses Conventional Commits format with Copilot co-author trailer.
- 2026-05-16 -- #223 logging consolidation
