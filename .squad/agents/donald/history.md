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
- `timeout 10 <cmd>` is the correct guard for any version-probe that might hit a network-dependent binary in Codespace; treat non-zero exit / timeout as unknown version, not an error
- In Codespaces, always check `gh copilot --version` (via timeout) before falling through to `npm install -g` -- the gh extension already provides copilot capability, and the npm postinstall can deadlock without a TTY
- `CI=true` + `--no-fund --no-audit` is the minimum npm non-interactive guard; mirrors the `is_non_interactive()` pattern already in `auth.sh`
- Any npm-dependent tool script that runs under `setup.sh` must source `~/.nvm/nvm.sh` in its own process and `nvm use default` before `command -v npm`; sibling `bash "${tool_script}"` subprocesses do not inherit nvm PATH changes from `nvm.sh`

---
> Compressed 2026-05-18 (Jiminy S17 audit): pre-Sprint-12 entries archived to history-archive.md.

## Pre-Sprint-12 Summary

Full details in `.squad/agents/donald/history-archive.md`. Key work: Issues #68-#82 (stdout/stderr, CRLF, CI=true, Copilot CLI install); PR #146/#170 (test regressions, AllScope guard); #173/#176 (shell aliases); #178 (cross-platform prerequisites parity); #189 (uninstall scripts); #191 (Windows gh auth); verification batch V-2/V-4/V-10/V-12/V-14; rogue file cleanup; PR #244 review; #223 logging consolidation; hygiene retro.

### Sprint 12 -- PR #313: Issue #236 docs(.aliases): mark file as bash/zsh-only

- **What:** Added a header to `config/dotfiles/.aliases` stating the file is bash/zsh only (not POSIX), listing non-POSIX features in use (`[[ ]]`, `[[ =~ ]]`, `local`, `$BASH_VERSION` / `$ZSH_VERSION` shell-detection vars, `alias --` long-option terminator), documenting the loading pattern (sourced from ~/.bashrc / ~/.zshrc via `config/dotfiles/install.sh`), and warning `sh`/`dash`/`ash` users away.
- **Why:** Closes the V-10 follow-up from the 2026-05-04 verification batch -- POSIX-conformance for `.aliases` was rejected then. This issue makes that decision explicit at the top of the file so future audits / contributors do not re-litigate it.
- **Files:** `config/dotfiles/.aliases` (header), `README.md` (Shell Aliases section adds a "bash/zsh only -- see header" pointer), `CHANGELOG.md` (Unreleased / Changed entry).
- **Out of scope (held):** Did NOT rewrite any aliases, did NOT add new aliases, did NOT do shellcheck fixes. Pure documentation.
- **Lesson:** A "do not chase X" decision is easier to defend when the file itself documents the non-X features it relies on. Header doubles as a reviewer cheat-sheet and as a contract with anyone tempted to `sh ~/.aliases`.


### Sprint 19 -- PR #415: Codify changelog-fold-completeness as script

- **What:** Implemented `scripts/changelog-fold.sh` (POSIX bash) and `scripts/changelog-fold.ps1` (PowerShell) to automate the CHANGELOG fold recipe from `.copilot/skills/changelog-fold-completeness/SKILL.md`. Added `tests/test_changelog_fold.ps1` (5 tests, all pass). Updated SKILL.md to reference the new scripts.
- **CLI:** `--release-version` (required), `--last-tag`, `--release-date`, `--changelog-path`, `--dry-run` (default), `--apply`. Idempotency gate exits 1 if version already present.
- **Key fixes:** (1) `[[ -n ]] &&` compound in `$()` with `set -e` aborts subshell -- replaced with unconditional `printf`. (2) PowerShell here-strings write CRLF, breaking bash stub shebangs in tests -- fixed via `[System.IO.File]::WriteAllText` with `($lines -join "\`n")`. (3) Scoop jq shim hits arg-length limit on large JSON -- pre-combined arrays via stdin instead of `--argjson`. Live dry-run against 0.9.8..HEAD: 104 PRs + 51 issues processed cleanly.

### Sprint 17 -- PR #389 (closes #382): Sprint-end label automation with verification

- **What:** Hybrid (C) delivery -- standalone bash script `scripts/sprint-end-labels.sh` and matching workflow `.github/workflows/sprint-end-labels.yml`. For every issue/PR carrying a given sprint label, removes `release:backlog` (if present) and adds `release:shipped-X.Y.Z` (if missing). Never touches type/area/squad/priority labels.
- **The Earl directive:** every `gh issue edit --add-label`/`--remove-label` is paired with a re-query (`gh issue view <N> --json labels`) that asserts the desired state. On mismatch, retry the **read** (never the write) on exponential backoff 1s/2s/4s, then fail loudly with the actual label set in the error. Implemented as `verify_with_retry` calling `has_label`. Skill formalized at `.squad/skills/gh-label-verify-retry/SKILL.md`.
- **Tests:** `tests/test_sprint_end_labels.ps1` (6 PASS). The retry-loop tests do not use a fake `gh`; they source the script's helpers into a bash shim and override `has_label` directly. This was the second attempt: the first tried to plant a `gh` shim on PATH but Git Bash on Windows kept resolving the real `gh.exe`, so function override is more portable. Backoff wall-clock (1+2+4 + 1+2+4 = 14s) is observable in test timing.
- **Idempotency:** double-checked by the skip-add/skip-remove branches that key on the **pre-fetched** label list (not on `gh edit` exit code). A second invocation reports `skip remove: ... not present` / `skip add: ... already present`.
- **Workflow safety:** `dry_run` input defaults to `'true'` -- operator must consciously flip it. Workflow uses `permissions: issues: write, pull-requests: write, contents: read` (least privilege for the job).
- **Sprint-16 dry-run probe:** `sprint:16` does not exist as a label in this repo (sprint labels weren't in use during S16). The script handled the empty result cleanly (`found 0 ... nothing to do`). Cross-validated the per-issue branch by running a dry-run with `release:backlog` as the search label, which produced clean DRY-RUN lines for 26 closed items.
- **Gotcha caught locally:** `Get-Command bash` on Windows returned `C:\Windows\system32\bash.exe` (the WSL stub), which choked on the script with "no installed distributions." Test now prefers explicit Git Bash paths (`C:\Program Files\Git\bin\bash.exe`) and falls back to PATH lookup that skips `System32\bash.exe`. Lesson: any bash-via-PowerShell script should never `Get-Command bash` without filtering the WSL stub.
- **Ancestry fixup:** branch was forked from a develop ancestor 4 commits behind tip; rebased onto `origin/develop` before commit to satisfy pre-commit ancestry check. `git stash push -u` + `rebase` + `stash pop` was needed because the new files were staged.
- **Out of scope:** did NOT introduce live label writes during testing; did NOT add a `sprint:N` label vocabulary; did NOT modify any existing workflow.
- **Lesson:** when a write API has any read-after-write delay, treat "the CLI returned 0" as a hint, not a guarantee. A 3-step exponential backoff costs ~7s in the worst case and removes a whole class of silent-miss bugs from batch automation.

### Sprint 18 Wave 1 -- #400: sprint-end-labels.sh first live production run

- **What:** First live production run of `scripts/sprint-end-labels.sh`. Chose input scheme (A): backfill `sprint:17` onto Sprint 17 closed issues (#371, #381, #382, #383, #384) and merged PRs (#385-#396), then ran the script live. Also created `sprint:17`, `sprint:18`, and `release:shipped-0.9.7` labels, establishing the sprint label scheme going forward.
- **Bugs surfaced (2):**
  1. **PRs excluded from query** -- `gh issue list --search` silently appends `is:issue`, excluding all PRs. Fix: query issues via `gh issue list --state closed` and PRs via `gh pr list --state merged` separately, then combine + deduplicate with `jq -n '$issues + $prs | unique_by(.number)'`.
  2. **Windows jq CRLF breaks idempotency guard** -- Windows `jq` outputs `\r\n`. The trailing `\r` attached to the last label in the TSV field caused the grep match to fail, so already-labeled items appeared to need re-labeling. Fix: pipe jq output through `tr -d '\r'` before the `while read` loop.
- **Verification:** All 17 adds verified on first read (0 retries). Earl directive satisfied.
- **Idempotency:** Confirmed on 3rd run: `total=17 changed=0 already-correct=17`.
- **Tests:** 6 -> 7 (new Test G: CRLF regression, function-override shim).
- **PR:** #403 (squash-merged to develop @ c03b2d2)
- **Lesson:** `gh issue list --search` is issues-only even with the search API; must pair with `gh pr list` for combined automation. Windows jq CRLF is a latent trap in any bash script that reads jq TSV output on Windows.

### Sprint 19 Wave 2 -- PR #432 (closes #429): Repair setup.sh idempotency bugs

- **What:** Fixed 4 pre-existing idempotency bugs in setup.sh (2 zsh entries in /etc/shells, 6x NVM_DIR + 2x .local/bin + 2x nvm.sh in ~/.zshrc) caught by tests/test_idempotency.sh after it was wired into CI in PR #426.
- **Root causes:** (1) zsh.sh appended to /etc/shells inside a SHELL != ZSH_PATH check, which re-ran on second execution before the user logged out to refresh $SHELL; (2) append_managed_block in dotfiles/install.sh ran grep on a file that might not exist, causing the idempotency marker check to fail silently.
- **Fixes:** (1) Moved /etc/shells check outside the shell comparison, using grep -qxF for exact line match; (2) Added touch before marker check to ensure file exists.
- **Strategy chosen:** Per-line idempotency guards (grep checks) over block-marker deletion+rewrite -- simpler, safer, proven pattern.
- **PR:** #432 (commit a1b4e12, branch squad/429-setup-idempotency)

---

## Team Update: 2026-05-27 -- Domain-Aligned PR Reviewers (Issue #444, PR #445)

**Status:** Donald now authorized to approve PRs wholly within the shell-scripts/Unix-install domain.

**What:** Implemented domain-aligned PR reviewers model to parallelize review and unblock the single-reviewer bottleneck on Mickey. Agents with domain expertise are now authorized to approve PRs that are wholly inside their review lane, with Mickey retained for governance, architecture, and cross-domain reviews.

**Donald's domain:** shell scripts and Unix install paths (scripts/linux/*, setup.sh, shell-specific configs/templates, dotfile templates for Unix shells)

**Operating rule:** Use `.squad/routing.md` as the source of truth for path-based PR review routing. Rejections follow the existing lockout rule: original author may not revise rejected artifact; next revision requires a different agent.

**Related:** PR #440 (idempotency fix) approved by Mickey; PR #445 implements the new model.