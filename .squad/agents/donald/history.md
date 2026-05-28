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
> **SUMMARIZED 2026-05-28:** Pre-Sprint-13 entries compressed. See history-archive.md for full details (Sprints 1-11, patterns, and early learnings).

### Sprint 19 -- PR #415: Codify changelog-fold-completeness as script

- **What:** Implemented `scripts/changelog-fold.sh` (POSIX bash) and `scripts/changelog-fold.ps1` (PowerShell) to automate the CHANGELOG fold recipe from `.copilot/skills/changelog-fold-completeness/SKILL.md`. Added `tests/test_changelog_fold.ps1` (5 tests, all pass). Updated SKILL.md to reference the new scripts.
- **CLI:** `--release-version` (required), `--last-tag`, `--release-date`, `--changelog-path`, `--dry-run` (default), `--apply`. Idempotency gate exits 1 if version already present.
- **Key fixes:** (1) `[[ -n ]] &&` compound in `$()` with `set -e` aborts subshell -- replaced with unconditional `printf`. (2) PowerShell here-strings write CRLF, breaking bash stub shebangs in tests -- fixed via `[System.IO.File]::WriteAllText` with `($lines -join "\`n")`. (3) Scoop jq shim hits arg-length limit on large JSON -- pre-combined arrays via stdin instead of `--argjson`. Live dry-run against 0.9.8..HEAD: 104 PRs + 51 issues processed cleanly.

### Sprint 17-18 (compressed) -- label automation and production run

- PR #389: Sprint-end label automation with read-after-write verification (`.squad/skills/gh-label-verify-retry/SKILL.md`).
- PR #403: First production run, 17 issues labeled (0 retries). Discovered gh issue list excludes PRs, Windows jq CRLF breaks idempotency.

### Sprint 19 Wave 2 -- PR #432 (closes #429): Repair setup.sh idempotency bugs

- **What:** Fixed 4 pre-existing idempotency bugs in setup.sh (2 zsh entries in /etc/shells, 6x NVM_DIR + 2x .local/bin + 2x nvm.sh in ~/.zshrc) caught by tests/test_idempotency.sh after it was wired into CI in PR #426.
- **Root causes:** (1) zsh.sh appended to /etc/shells inside a SHELL != ZSH_PATH check, which re-ran on second execution before the user logged out to refresh $SHELL; (2) append_managed_block in dotfiles/install.sh ran grep on a file that might not exist, causing the idempotency marker check to fail silently.
- **Fixes:** (1) Moved /etc/shells check outside the shell comparison, using grep -qxF for exact line match; (2) Added touch before marker check to ensure file exists.
- **Strategy chosen:** Per-line idempotency guards (grep checks) over block-marker deletion+rewrite -- simpler, safer, proven pattern.
- **PR:** #432 (commit a1b4e12, branch squad/429-setup-idempotency)

### Issue #441 grill v4 -- 2026-05-27 (session: 441-grill-v4)

- **Verdict:** REVISE
- **Key findings (4):** [HIGH] F-1 missing `-Encoding ASCII` on orphan-strip Set-Content (P1 introduced, production bug if shipped); [MEDIUM] F-2 "TestDrive" in GG-4 contradicts Section 3 D2 (Pester rejected as scope creep); [MEDIUM] F-3 $LASTEXITCODE stale contamination -- success-path mocks don't reset after GG-7's `exit 1`, ordering not guaranteed; [MEDIUM] F-4 orphan-strip regex diverges from production pattern without rationale (dropped \r?\n prefix, .+? vs .*?)
- **P1-P7 regression patches:** all RESOLVED; algorithm sound
- **Implementation readiness:** NOT ready today -- F-1 encoding bug is a concrete production defect; F-2 forces implementer guess on TestDrive vs real paths
### Issue #441 v5 revision -- 2026-05-27 (session: 441-v5-revision)

- **Role:** Reviser (authored v3; grilled v4 as Donald)
- **What patched (5 holes):**
  - H1 [HIGH]: Added `-Encoding ASCII` to orphan-strip `Set-Content` in Section 4 foreach body. Production line 28 precedent. One word.
  - H2 [MEDIUM]: Section 5 header -- added `0 = 0` per-test reset requirement; removed misleading BeforeEach reference. Prevents GG-7 stale exit-1 from contaminating success-path tests.
  - H3 [MEDIUM]: GG-4 Input column -- replaced `TestDrive` with `Join-Path $env:TEMP "gg-test-441-$(New-Guid)"` temp-path language; added temp-dir cleanup sentence to Section 5 header. Resolves Pester contradiction with D2.
  - H4 [MEDIUM]: GG-7 Input column -- specified `$HostExe = 'powershell'` (guaranteed on Windows); added note that `'pwsh'` would mask not-installed early-exit branch.
  - H5 [MEDIUM]: Added two `$local:ps51Fallback`/`$local:ps7Fallback` definitions at top of `Write-PowerShellProfile` in Section 4 code block. Mirrors production lines 17-19; required under `Set-StrictMode -Version Latest`.
- **Word count:** v4 ~1020 words -> v5 ~1130 words (+~110; within target ceiling of 1100+tolerance)
- **Vertical slice:** preserved -- no new tests, no new architectural layers, no new parameters; GG-1..GG-7 unchanged in count and identity
- **Earl directive:** "keep vertically sliced and cleanly scoped" -- satisfied; all patches are 1-word, 1-line, or 1-sentence

### Issue #441 v5.1 patch -- 2026-05-27 (session: 441-v5.1-patch)

- F-4: Orphan-strip regex updated to match production line 27 (\r?\n prefix added; .+? -> .*?); no stray blank line risk.
- F-5: $local:beginMarker/$local:endMarker defined at top of Write-PowerShellProfile alongside H5 fallbacks, mirroring production lines 12-13; resolves VariableIsUndefined under Set-StrictMode.

## 2026-05-27 -- Team Update

- Pluto shipped v5.2 profile-path fix in PR #458; review in flight.

### #468 plan grill -- 2026-05-28 (PR #470)

- **Verdict:** REQUEST CHANGES (3 HIGH, 2 MEDIUM)
- **[HIGH-1]** `--list` sed pseudocode: `sed 's/\.sh$//'` strips extension but not path prefix. Bare tool names required for `--only=` matching. Fix: `basename "$f" .sh` loop.
- **[HIGH-2]** Default list order unspecified. Filesystem scan = alphabetical = `auth` before `gh`, `copilot-cli` before `nvm` on fresh install. Both silently degrade. Default must be a hardcoded array in current declaration order (`zsh uv nvm gh auth copilot-cli squad-cli`).
- **[HIGH-3]** Opt-in vs default tool distinction has no mechanism. Plan promises delta/lazygit are "not in default install" but no gate exists. Hardcoded default array is the gate -- must be stated explicitly.
- **[MEDIUM-4]** "No DAG needed" is wrong. `copilot-cli.sh` and `squad-cli.sh` silently skip if npm not present; `auth.sh` silently skips if gh absent. Not independent -- gracefully degrading.
- **[MEDIUM-5]** Bash arg-parsing mechanism unspecified. `getopts` doesn't support `--long-opts` and returns 1 at end of args (kills under `set -euo pipefail`). `case`-based loop is the correct pattern.
- **Key lesson:** When a plan introduces a dynamic default list (filesystem scan), verify it preserves the existing tool ordering. Alphabetical != safe. Any plan asserting "tools are independent" must be tested against the actual tool scripts' early-exit guards.

### #468 v2 plan re-grill -- 2026-05-28 (PR #470)
- **Verdict:** APPROVE (comment-only). v2 concretely fixes `--list` basename output, explicit default order, and delta/lazygit opt-in gate; baseline now checks order.
- **Implementation note:** add blank CSV token validation/tests (`--only=uv,`, `--only=uv,,nvm`) so Bash `read -ra` cannot silently accept malformed lists.

### #468 v3 plan re-grill -- 2026-05-29 (PR #470)
- **Verdict:** REQUEST CHANGES. Bash blockers: root forwarding must call `run_linux_setup "$@"`; `--tools-dir` doesn't mock AlwaysRun; trailing CSV comma is not caught by `IFS=',' read -ra`; baseline Makefile source/exit seam is inconsistent.

### #468 v4 plan re-grill -- 2026-05-30 (PR #470)
- **Verdict:** REQUEST CHANGES. V4 fixes D1-D3 and drops AlwaysRun cleanly, but the new stub baseline is inconsistent: defaults.txt holds tool names while RUN_LOG records RAN:<tool>, so direct diff cannot pass.


### #468 v5 plan polish -- 2026-05-30 (PR #470)
- **Action:** Authored v5 polish pass (863671e). Fixed baseline format mismatch (bare tool names), git-hook self-guard (DK4-bis), real-defaults drift test (Duck-2). Documented --skip caveats.

### #468 v5 polish -- 2026-05-30 (PR #470, 863671e)
Authored v5: fixed baseline format, git-hook self-guard, real-defaults drift test.
