# Project Context

- **Owner:** Earl Tankard, Jr., Ph.D.
- **Project:** dev-setup -- A replicable setup script system for Dev Containers and Codespaces
- **Stack:** Bash, Zsh, PowerShell, shell scripting, cross-platform tooling
- **Created:** 2026-04-07T03:05:10Z

## Key Details

- Goal: Auto-detect OS (Linux, Windows, macOS) and run the appropriate setup script
- Target environments: GitHub Codespaces, Dev Containers, fresh machines
- Tools to install: zsh, uv, nvm, gh CLI, GitHub Copilot CLI, and user shortcuts
- Dotfiles and shell configs are managed as templates
- Scripts must be idempotent -- safe to run multiple times

## Core Context

**Sprints 1-7 Summary (2026-04-07 to 2026-05-04):**

Implemented Linux/macOS tool installer scripts and cross-platform CLI tooling:

- **Sprints 1-4:** 6 tool install scripts (zsh, uv, nvm, gh CLI, GitHub Copilot CLI, auth); shell profile injection for multiple shells (.bashrc, .zshrc); idempotency across multiple runs
- **Sprint 5:** gh 2.89.0+ built-in promotion handling (`gh copilot -- --help` passthrough); CI=true env var for isatty()-gated CLI probes; Copilot CLI download workarounds (PTY script, stdin pipe, final CI=true fix); exec 2>&1 stderr/stdout merge; CRLF guard in devcontainer
- **Sprint 6:** tmux addition to prerequisites; issue #138 (dual-path profile, AllScope alias guards)
- **Sprint 7-8:** vim PATH permanence via registry SetEnvironmentVariable

**Key Patterns Established:**
- `set -euo pipefail` + `exec 2>&1` for ordered diagnostic output
- gh built-in probe: never use `--help` alone; always use `-- --help` to pass through to binary; never use `gh extension list` or `gh alias list` as idempotency gate
- `CI=true timeout 60 gh copilot >/dev/null 2>&1 || true` for non-interactive Copilot binary download (isatty() gate bypass)
- Shell function sourcing required for nvm validation (not a binary)
- uv prefers `~/.local/bin` for non-login shells; export explicitly
- Idempotency: skip+warn pattern when optional tools missing (npm, gh)

**Key Files:**
- `scripts/linux/setup.sh` -- orchestrator: prerequisite install, run_tool helper, profile injection
- `scripts/linux/tools/*.sh` -- 6 tool scripts + auth; each has `set -euo pipefail`, idempotency guard at top
- `.gitattributes` -- eol=lf for *.sh; paired with devcontainer CRLF strip guard

**Tech Debt Addressed:**
- ps.tar.gz binary artifact removed (69MB compiled PowerShell/.NET SDK)
- .gitignore updated to prevent future binary commits (*.tar.gz, *.zip, *.dll, *.exe)

---

## Learnings

! **TEAM REQUIREMENT:** Read `.squad/skills/ps51-ascii-safety/SKILL.md` before touching any `.ps1` file. This skill captures the CP1252 encoding trap, detection scripts, and fix patterns.

- Never probe gh built-ins with `--help` alone -- use `gh copilot -- --help` to reach binary; `--` passes flag through unconditionally
- Never use `gh extension list | grep` or `gh alias list | grep` as sole idempotency gate -- always probe actual command with `--help`
- gh alias conflict blocks extension install silently (stdout, not stderr) -- guard with delete before install
- `CI=true` is correct non-interactive trigger for any gh built-in that gates on `IsCI()`; never use `CanPrompt()` in postCreateCommand (no TTY)
- `script(1)` PTY is right tool for isatty-gated CLIs but not when parent pipe may close early (e.g., container lifecycle hooks)
- Directory existence check for Copilot binary: `~/.local/share/gh/copilot` (not exit code probe)
- sed -i 's/\r//' chosen over dos2unix for POSIX portability

---
> Compressed 2026-05-17 per #319 (Option A: older entries summarized in-place; no archive file).

## Recent Work (pre-Sprint-9 summary)

Compressed; full detail dropped in favor of preserved lessons in Learnings.

- **2026-04-12 to 2026-04-13** Issues #68/#69 stdout/stderr merge + CRLF guard (PR #70/#71 merged). Issue #72 directory-based install check + printf pipe (PR #73 merged). Issues #75/#76 vim prerequisites + script PTY for Copilot CLI (PRs #77/#78). Issue #76 revised: standalone copilot-cli install via official script (PR #82).
- **2026-04-12 -- Issue #79 / PR #80** CI=true env var to bypass non-interactive Copilot binary download (isatty()/IsCI gate fix). Root cause traced in cli/cli source.
- **2026-04-13 to 2026-04-25** PR #146 test regressions fixed (Issue #138), PR #170 Remove-Item AllScope guard for `ep` alias.
- **2026-04-19** Issue #138 lead session wrap-up (dual-path profile + force-alias).
- **2026-05-04** Issue #173 / PR #176 shell aliases for shutdown control. Post-sprint Linux shell audit (2026-05-16).

Lessons preserved verbatim in Learnings section above (gh built-in `--` passthrough, CI=true non-interactive trigger, exec 2>&1 for ordered output, CRLF onCreateCommand guard, directory check over exit-code probe).

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

## Learnings

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
2026-05-16 -- #223 logging consolidation

### Sprint 12 -- PR #313: Issue #236 docs(.aliases): mark file as bash/zsh-only

- **What:** Added a header to `config/dotfiles/.aliases` stating the file is bash/zsh only (not POSIX), listing non-POSIX features in use (`[[ ]]`, `[[ =~ ]]`, `local`, `$BASH_VERSION` / `$ZSH_VERSION` shell-detection vars, `alias --` long-option terminator), documenting the loading pattern (sourced from ~/.bashrc / ~/.zshrc via `config/dotfiles/install.sh`), and warning `sh`/`dash`/`ash` users away.
- **Why:** Closes the V-10 follow-up from the 2026-05-04 verification batch -- POSIX-conformance for `.aliases` was rejected then. This issue makes that decision explicit at the top of the file so future audits / contributors do not re-litigate it.
- **Files:** `config/dotfiles/.aliases` (header), `README.md` (Shell Aliases section adds a "bash/zsh only -- see header" pointer), `CHANGELOG.md` (Unreleased / Changed entry).
- **Out of scope (held):** Did NOT rewrite any aliases, did NOT add new aliases, did NOT do shellcheck fixes. Pure documentation.
- **Lesson:** A "do not chase X" decision is easier to defend when the file itself documents the non-X features it relies on. Header doubles as a reviewer cheat-sheet and as a contract with anyone tempted to `sh ~/.aliases`.


### Sprint 12 Wave 2 -- PR #N (closes #237): Test harness pattern docs
- Documented the bash test harness convention in CONTRIBUTING.md as a new `Test Harness Pattern` top-level section. Convention: tests in `tests/*.sh` use `set -uo pipefail` (NOT `-euo`) so individual assertion failures do not abort the suite; PASS/FAIL state is tallied via counters and the script exits non-zero only when `FAIL > 0`. `-euo` is acceptable when every potentially-failing command is wrapped in `if` / `||`.
- Covered the gotcha for contributors: a well-meaning `-e` addition to a tally suite breaks it silently because the first failing assertion aborts before the tally can finish; CI sees a partial run.
- Reference files cited: `test_idempotency.sh` (canonical complex suite + `assert_*` helpers), `test_aliases.sh` (mock subcommands), `test_tool_versions.sh` (smallest minimal), `test_precommit_hygiene.sh` + `test_shared_logging.sh` (valid `-euo` use).
- Provided a copy-paste skeleton for new `tests/test_<thing>.sh` files: `-uo` + `PASS`/`FAIL` counters + `pass()`/`fail()` one-liners + final `if [ "FAIL" -gt 0 ]; then exit 1; fi`.
- Authored `.squad/skills/test-harness-pattern/SKILL.md` (confidence: medium, domain: testing). Skill captures the rule, the rule of thumb, the counter-naming variance, the path-setup boilerplate, the helper convention, and four anti-patterns (notably the `((PASS++))` exit-code-1 trap under `set -e`).
- Cross-link: CONTRIBUTING.md's new section sits between Parallel Agent Work and Group Letter Assignment, so the testing sections cluster.
- Out of scope (per ticket): refactoring tests, adding new tests, changing `set -*` flags in existing files, PowerShell test harness.
