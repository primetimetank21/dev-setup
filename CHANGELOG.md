# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

### Changed

### Fixed

### Removed

- Embedded squad infrastructure: removed `.squad/` directory and all internal AI-agent coordination tooling from the repository. Project coordination now handled externally. (PR #475, PR #477)
- Branch naming convention changed from `squad/{issue}-{slug}` to `feat|fix|chore|docs|refactor/{issue}-{slug}` (conventional commit prefixes).
- Removed all `squad-cli` tool references from documentation and examples.

## [0.9.8] - 2026-05-19

### Added
- Mandatory hygiene tail template and routing.md section enforcing 6-item discipline at every spawn (#397/#401)
- Two new hygiene skills formalized: `history-md-pre-size-check` and `changelog-fold-completeness` (#398/#399/#402)
- Sprint label vocabulary standardized: `sprint:17`, `sprint:18`, `release:shipped-0.9.7` introduced and backfilled across S17 work (#400/#403)
- Test G in `tests/test_sprint_end_labels.ps1` -- CRLF regression coverage via function-override shim (#403)
- Sprint 18 decision archive (#408)

### Changed
- `scripts/sprint-end-labels.sh`: combined `gh issue list` + `gh pr list` queries (issue-list silently excludes PRs); pipe jq through `tr -d '\r'` for Windows CRLF safety (#403)
- Agent history files compressed under 15360 B gate per `history-md-pre-size-check` SKILL (#404)

### Fixed
- `gh issue list --search` PR-exclusion bug in sprint-end-labels automation -- script now correctly processes both issues and PRs (#403)
- Windows jq CRLF idempotency-guard bypass in sprint-end-labels script -- already-labeled items no longer re-labeled on subsequent runs (#403)
- Sprint 18 attribution trail gaps via fixup PRs #406, #407

## [0.9.7] - 2026-05-17 -- Sprint 17: Hygiene gate restoration + label automation + skill formalization

### Added

- Sprint-end label automation: `scripts/sprint-end-labels.sh` + `.github/workflows/sprint-end-labels.yml`. Applies `release:shipped-X.Y.Z` and removes `release:backlog` across all issues/PRs carrying a given sprint label. Hard-verifies every label op via re-query with 3-retry exponential backoff (1s, 2s, 4s). Dry-run mode (`--dry-run`) for safe rehearsals. Type/area/priority labels are never touched. Covered by `tests/test_sprint_end_labels.ps1` (6 tests, including happy-path and fail-loudly retry scenarios). New skill formalizes the write-then-verify-then-retry pattern. (#382)
- New skills formalized: `gh-pr-base-develop` (high-conf, --base develop enforcement pattern), `worktree-remove-first` (medium-conf, worktree-remove-before-merge quirk), `gh-label-verify-retry` (high-conf, write-then-verify-then-retry pattern). (#383, #384, #382)
- Per-sprint decisions sub-folders introduced: `sprint-12.md` and `sprint-15.md` added; sub-folder policy documented. (#371)

### Changed

- README refresh: expanded roster, updated hooks list, hygiene gates, and skill ecosystem pointer for v0.9.6 state. (#381)
- `decisions.md` restructured to current-sprint-only live file; gate restored from 65737 B to 7228 B. (#371)
- `routing.md`: spawn-prompt hygiene section added. (#384)

### Fixed

- `.gitignore` em-dash artifact removed. (#390)

### Removed

## [0.9.6] - 2026-05-17 -- Sprint 16: Skill formalization + hygiene gate review

### Added

- Sprint 16 skill drift watchlist audit documented. (#367)
- New skill formalizing the "self-documenting non-ASCII" discipline (medium confidence). (#362)
- New skill formalizing the stale-sprint-branch recovery pattern (low confidence). (#364)

### Changed

- Decisions ledger archival pass -- 1 stale entry moved to archive. Hard gate (51200 B) not met mid-sprint; follow-up #371 filed for policy review. (#363)
- Tag prefix sanity check -- 14/14 tags conform to bare X.Y.Z convention, no drift. (#365)

### Fixed

### Removed

## [0.9.5] - 2026-05-17 -- Sprint 15: Legacy non-ASCII sweep + Sprint number normalization

### Added
- Sprint 14 retro (retroactive Sprint 14 artifact, folded into 0.9.5)
- Canonical decision record documenting sweep scope, methodology, and conversion mapping table (#359)

### Changed
- Normalized historical Sprint letter references (Sprint R/S/T) to numbers (Sprint 11/12/13) in CHANGELOG.md historical entries for consistency with current Sprint NN numbering (#355).
- Swept legacy non-ASCII characters (em-dashes, smart quotes, box-drawing) from 33 tracked .md files; ~1250 non-ASCII bytes removed (#356).
- history-compression skill: confidence medium -> high (8+ applications in Sprint 14)
- per-topic-inbox-routing skill: confidence medium -> high (7+ applications in Sprint 14)

### Fixed

### Removed

## [0.9.4] - 2026-05-17

### Added
- history-compression skill formalized at confidence: medium -- 4-step heuristic, 13 KB target with 2 KB headroom under the 15360 B hard gate (#340)
- per-topic inbox routing skill formalized at confidence: medium -- routing decision tree, atomic-rm model, dual-model coexistence with chronological journal (#341)

### Changed
- README refreshed: pre-commit 6-check description (F1), ascii-sweep.py docs (F2), file-tree hand-converted to ASCII (F3), file-tree updated (F4), pre-commit one-liner expanded (F5) (#342)
- Label taxonomy slimmed from 45 to 32 labels (drop 8 GitHub-default duplicates, 4 stale release version labels, 1 lonely status label; rename area:linux/macos/windows -> platform:*) (#347)
- Label sync workflow: add priority:p3 + platform:* to managed labels, remove dead hasCopilot code (#350)

### Fixed

### Removed

## [0.9.3] - 2026-05-17 -- Sprint 13: Documentation accuracy and ASCII policy hardening

### Added
- Skill formalizing the worktree-remove-FIRST PR merge pattern; documents the gh CLI quirk and proven 5-of-5 workaround (#317)
- Sprint 13 retrospective (#339; folded retroactively into 0.9.3 -- PR merged after tag)

### Changed

- docs: ASCII-sweep all repo Markdown files (em-dash, arrows, smart quotes, box-drawing) per repo policy (#322 part A)
- Compress over-gate agent history.md files per HARD GATE (#319)
- Fold Sprint 13 Wave 1 hygiene drops into per-topic decisions and re-compress history files
- Fold Sprint 13 Wave 2 hygiene drops into per-topic decisions and re-compress 4 over-gate agent history.md files

### Fixed
- docs(architecture): correct stale top-level path for auth.ps1; reflects post-PR #297 move to tools/ (#325)
- docs(readme): correct active git hooks count from three to four; lists prepare-commit-msg post-PR #212 (#326)
- hooks(pre-commit): extend non-ASCII scan to include .md and .sh files (was .ps1 only, allowing 134 non-ASCII hits to land in ARCHITECTURE.md) (#322 part B)

### Removed

## [0.9.2] - 2026-05-17

### Added
- `tests/test_windows_setup.ps1` Group FF (FF-1 through FF-10): idempotency + restore coverage for `scripts/windows/uninstall.ps1` -- 5 static-source checks (managed dotfile list, newest-wins backup selection, Move-Item -Force usage; Linux uninstall.sh parity) + 5 functional checks (newest timestamped .bak.* wins, legacy .bak fallback, second-run idempotency on dotfiles, profile-block removal preserves surrounding content, second-run idempotency on profile). Functional tests run uninstall.ps1 in a child powershell process with USERPROFILE/HOMEDRIVE/HOMEPATH redirected to a tmp HOME so the script's `$HOME` resolves to throwaway state, and pin CWD to a tmp git repo so `git config --unset-all core.hooksPath` cannot affect the user's real config (closes #238)
- CONTRIBUTING.md `Test Harness Pattern` section: documents the `set -uo` (intentionally NOT `set -euo`) convention for bash tests; failure tally pattern, helper conventions, minimal skeleton (closes #237)

### Changed
- README.md: refreshed to reflect Sprints 8-12 changes (auth.ps1 path move, .tool-versions pinning, expanded roster, decisions/retros workflow, numeric sprint naming convention, ARCH/CONTRIB cross-references) (closes #306)
- ARCHITECTURE.md: documented Windows orchestrator dependency order chain; mirrors the Linux Dependency Order section for parallel install flow visibility (closes #310)
- ARCHITECTURE.md: rewrote `Script Conventions` section to point at `scripts/{linux,windows}/lib/` as source of truth; documents `source` / dot-source loading + `Read-ToolVersion.ps1` parser pattern (closes #309)
- Sprint naming convention standardized to numeric format: Sprint 8-hotfix, Sprint 9, Sprint 10, Sprint 11; next = Sprint 12. Tier 3 full sweep across 21 files (~170 refs). Retro files renamed with `git mv`. Historical sprint letter references removed in favor of numeric format for consistency. CONTRIBUTING.md "Sprint Naming Convention" section updated with current numeric convention.
- `.aliases`: added header marking the file as bash/zsh-only (not POSIX); documents non-POSIX features in use and intended loading pattern (closes #236)
- Decision log drained and restructured; archive gate crossed (57 KB >= 50 KB) but no entries eligible for 7-day cut (Sprint 12 Wave 2 fold)
- Sprint 12 retrospective (3 waves, 10 PRs, 9 issues closed, worktree-isolation + ASCII-scope lessons learned)

### Removed
- Legacy GitHub labels `priority: high`, `priority: medium`, `priority: low` (with spaces) deleted; canonical taxonomy is now `priority:p0..p3` (closes #254)

## [0.9.1] - 2026-05-17 -- Sprint 11: Architecture refresh and tools hardening

### Fixed
- `scripts/windows/tools/auth.ps1` + `scripts/windows/setup.ps1`: applied `$LASTEXITCODE` reset mitigation at 5 sites; eliminates spurious failure detection when callers check exit codes downstream (closes #292)

### Added
- PowerShell exit-code discipline skill: documents the `$LASTEXITCODE` propagation gotcha across pwsh `&` script-call boundaries; canonical fix is `$global:LASTEXITCODE = 0` after expected-failure commands (closes #288, surfaced by #277)
- CONTRIBUTING.md "PowerShell Exit Code Discipline" section referencing the new skill
- Decision record codifying the post-batch audit gate and the subagent worktree pattern (closes #289, #290)
- Sprint 11 retrospective - first sprint exercising the SOPs (gates fired clean, worktree not triggered); 6 PRs merged, sequential pattern validated, Group EE static-source tests added

### Changed
- `scripts/windows/auth.ps1` moved to `scripts/windows/tools/auth.ps1` for consistency with the per-tool layout; all callers updated (closes #230)
- ARCHITECTURE.md: refreshed file trees + rosters + hook + CI layout to reflect Sprint 8-hotfix through Sprint 10 changes (closes #229)
- `hooks/pre-push`: documented advisory-only intent of the PSScriptAnalyzer step with an inline comment block at the top of the PSSA section; clarifies that PSSA findings warn but do not block (closes #233)
- `CONTRIBUTING.md` "Why is PSSA advisory in `pre-push`?" subsection under Git Hooks: codifies the advisory model for contributors (closes #233)
- Templates and charters: codify post-batch audit gate + subagent worktree pattern; eliminates the dual-fold-PR overhead of Sprint 10 (closes #289, #290)
- `CONTRIBUTING.md` operational gates section -- human-facing summary of the worktree + auto-dispatch SOPs
- `hooks/pre-commit` Source of Truth allow-list extended to include canonical decision files (top-level decisions directory, distinct from the gitignored `inbox/` subdir).
- Sprint 11 end-of-session cleanup: no straggler branches/worktrees

## [0.9.0] - 2026-05-17 -- Sprint 9 + Sprint 10: Hygiene backlog and tool-version pin sweep

### Added
- Static source checks verifying that scripts read pins from `.tool-versions` and perform version-aware idempotency (closes #255)
- Regression sentinel asserting correct package is installed and that version output captures stderr (closes #255)
- Version-pin validation for Windows installers (closes #255)
- Behavioral tests for pre-commit (ASCII check) and pre-push (main guard, feature-branch allow, advisory exit-code) hooks (closes #224)
- Coverage for `-Encoding ASCII` enforcement in Windows profile and uninstall scripts (closes #234)
- Bash scenarios covering direct-to-main rejection and advisory exit-code (closes #224)
- Skill documenting the bare-idempotency anti-pattern and the canonical version-pin solution
- New generic error-recovery skill
- Reusable checklist for auditing future upgrade runs
- Fact checker agent joins the project -- addresses the verifier/validator gap. Auto-triggers on `review`/`verify`/`fact-check`/`audit` tasks; produces verification reports with confidence ratings.
- Label enforcement workflow for mutual exclusivity
- New templates from governance upgrade
- `hooks/pre-commit` now allows template files; allow-list extended to permit retro files so session retros can be committed
- "Develop Commit Ban" section -- documents that agents cannot commit directly to `develop`/`main`/`master`; EOS history entries flow through short-lived branch+PR or drain process (closes #273)
- CONTRIBUTING.md "Group Letter Assignment" section -- coordinator pre-assigns test group letters to prevent parallel-agent collisions; example documented (closes #273)
- CONTRIBUTING.md "CHANGELOG Conflict Strategy" section -- documents mechanical resolution for predictable [Unreleased] conflicts (closes #273)
- CONTRIBUTING.md "Tool Version Pin Enforcement" section -- documents the version-pin workflow and the npm-package validation step (closes #255)
- `.gitignore` now ignores `*.tgz` tarballs so upgrade artifacts cannot accidentally land in commits

### Changed
- `.tool-versions`: added tool pins and version corrections
- Windows tools now dot-source `Read-ToolVersion.ps1` to resolve pinned version at runtime
- Windows profile and uninstall scripts: added `-Encoding ASCII` to all `Set-Content` and `Add-Content` calls. Prevents encoding mismatch between PS 5.1 (UTF-16LE BOM default) and PS 7 (UTF-8 BOM default) (closes #234).
- `.gitattributes` now pins `*.ps1`, `*.psm1`, and `*.psd1` files to explicit CRLF line endings, eliminating platform divergence when `core.autocrlf` is enabled (closes #231).
- `setup.sh` and `scripts/linux/uninstall.sh` now source `scripts/linux/lib/log.sh` instead of defining their own logging helpers. Local definitions removed; all call sites updated to the canonical names (closes #223).
- Documentation: README + CONTRIBUTING now document the automatic `core.hooksPath` setup performed by setup scripts. Replaced stale "install hooks manually" instruction. Added branch-from-develop validation note.
- Governance upgraded (dispatch mechanism, CURRENT_DATETIME requirement, name param in spawn prompts, default models bumped, tier-based agent timeout policy)
- Workflows: heartbeat removes noisy cron trigger; label workflows add `slugify()` for label names (bugfix)
- Dotfile backup strategy: `.bak` files are now timestamped (`.bak.YYYYMMDD-HHMMSS`) on both Linux and Windows. Keeps last 5 backups by default (override with `DOTFILE_BACKUP_KEEP` env var) (closes #227).

### Fixed
- Tool install scripts: replace bare binary-exists guard with version-aware check; installs pinned version; upgrades silently if installed version drifts from pin (closes #255)
- Copilot CLI: switch install package from deprecated package to current; Windows switches from winget (wrong product) to npm for consistency with Linux; pin corrected (closes #255)
- Linux gh installer: now downloads pinned release tarball from GitHub releases instead of `apt-get install -y gh` (latest); macOS logs WARN if brew installs a version other than the pin (brew versioned formulae not available for gh) (closes #255)
- Windows gh installer: passes `--version $GhVersion` to winget so runner cache cannot silently use an older gh (closes #255)
- Uninstall scripts now run `git config --unset-all core.hooksPath` during uninstall (LOCAL scope) so git falls back to per-repo `.git/hooks` defaults; Windows path resets `$global:LASTEXITCODE = 0` after the unset (closes #271).
- E2E workflow -- adds a final `summary` job that fails the workflow if any platform job fails, preventing silent green-dashboard regressions. Per-platform jobs still use `continue-on-error: true` so full matrix telemetry is preserved (closes #253).
- Tool CLI warnings investigated; verified absent in version check path. Added regression guard: e2e workflow now captures version output and fails if warning appears. Static installer tests verify correct package name and stderr capture.
- Windows tool installers -- winget install calls now assert `$LASTEXITCODE` and surface failures (closes #226). 7 install sites previously swallowed non-zero exits silently.
- E2E workflow -- bash step bodies now use YAML doubled-single-quote escapes for embedded apostrophes.

## [0.8.0] - 2026-05-16 -- Sprint 8 + Sprint 8-hotfix (formerly Sprint Q): Gap audit refactor and install regression P0s

### Added
- Pre-commit hygiene checks: ASCII-only enforcement on staged `.ps1` files, path validation, staged file detection, and branch ancestry verification for feature branches (closes #240)
- `tests/test_precommit_hygiene.sh` -- bash tests for all 4 pre-commit hygiene checks (13 pass/fail cases)
- E2E install smoke test workflow `.github/workflows/e2e-install.yml` with 3-OS matrix (Linux, macOS, Windows) -- exercises full setup, tool assertions, idempotency, and uninstall on fresh runners (closes #239)
  - Triggers: per-PR, nightly cron (04:00 UTC), manual workflow_dispatch
  - Non-blocking initially (`continue-on-error: true` on all jobs); will flip to blocking after 2-3 green nightlies
  - Stabilization plan: monitor nightly runs for 1 week; address third-party flakes (winget rate limits, brew network); then remove continue-on-error
- macOS CI validation via new `validate-macos` job in `validate.yml` (closes #181)
- Windows GitHub auth step via `scripts/windows/auth.ps1` (closes #191)
- Automatic Node LTS install via nvm during setup; reads pinned version from `.tool-versions` (closes #201)
- `tests/test_nvm_bootstrap.sh` -- bash tests for nvm/squad-cli bootstrap behavior
- Group T tests in `test_windows_setup.ps1` for nvm.ps1 Node auto-install logic
- Group U tests in `test_windows_setup.ps1` for squad-cli.ps1 loud error behavior
- `.tool-versions` file for pinning tool versions (nodejs, nvm, uv, copilot-cli)
- `scripts/lib/read-tool-version.sh` -- POSIX sh helper to read pinned versions
- `scripts/lib/Read-ToolVersion.ps1` -- PowerShell `Get-ToolVersion` function
- `tests/test_tool_versions.sh` -- bash tests for version reader
- Group R tests in `test_windows_setup.ps1` for `Get-ToolVersion`
- CI shellcheck linting for `config/dotfiles/.aliases` in lint-shell-scripts job
- Uninstall scripts (`scripts/linux/uninstall.sh`, `scripts/windows/uninstall.ps1`) that revert profile blocks and restore dotfile .bak files. Tools remain installed.
- Windows now installs dotfiles (gitconfig, editorconfig, npmrc, vimrc) with .bak backup (PR #180)
- CI now runs `tests/test_git_hooks.ps1` to catch git hook regressions
- Alias parity test between Linux .aliases and Windows PowerShell profile (PR #187)
- Shutdown aliases: `sdn`, `tsdn`, `cancel_tsdn` for Windows and Linux (PRs #175-#177)
- Modular tool installer split -- 451-line `setup.ps1` monolith refactored into 76-line orchestrator + 9 per-tool files under `scripts/windows/tools/` (PR #195)
- PS 5.1 test groups N, O, P and ASCII-clean test runner (PR #200)
- `prepare-commit-msg` hook that rewrites git auto-generated merge/revert messages into Conventional Commits form (#212)

### Changed
- Shared logging helpers extracted to dedicated lib files (closes #186)
- Support for `merge` type in commit-msg hook type allowlist (#212)
- Tool install failure is now a loud error with actionable hints (was silent warning)
- Tool installers read versions from `.tool-versions` instead of fetching latest
- Made tmux auto-attach opt-in via `TMUX_AUTOSTART=1` env var (was always-on)
- Refreshed ARCHITECTURE.md and README.md file trees to match current repo layout
- commit-msg no longer needs special-case bypass for merge/revert -- prepare-commit-msg now normalizes them (#212)

### Fixed
- Windows: session PATH now refreshed after every `winget install` so just-installed binaries resolve immediately without restarting the terminal; preserves session-only PATH entries (closes #251)
- Windows nvm install switched from winget+nvm-setup.exe to portable nvm-noinstall.zip download (deterministic, no installer race); replaces polling with Install-NvmPortable + Set-NvmEnvironment (#251)
- Pinned Node.js version bumped to satisfy engine requirement; added `nvm alias default` so fresh shells inherit the pinned version; affects Linux, macOS, and Windows setup paths (fixes #252, related #255)
- E2E install workflow: added Node major version assertion (>=22) to Linux and macOS fresh-shell steps to prevent future regressions (#252)
- CI: Added nvm + Node.js validation step to validate-macos job, aligning with validate-linux (closes #225)
- Pre-commit hook now refuses commits directly on `develop`, `main`, or `master` with a clear error message directing the user to create a feature branch (closes #249)
- Windows nvm installer resolved wrong lib path; `Read-ToolVersion.ps1` not found at runtime (closes #221)
- Added runtime assertion in `nvm.ps1` to catch missing lib directory early
- PS 5.1 compat: psmux install skip-with-warning + profile write diagnostics

## [0.7.0] - 2026-04-25 -- Sprint 7: Hooks, psmux, and profile hardening

### Added
- Git hooks infrastructure: pre-push hook with PSScriptAnalyzer advisory check (PRs #131, #149)
- psmux (Windows tmux equivalent): winget install + aliases + `New-PsmuxSession` (PRs #141, #142)
- `ep` alias to open PowerShell profile in editor (PR #170)
- `Remove-Item` guards for `gcm` and `gcb` AllScope aliases (PR #161)
- README documentation for git hooks auto-configuration (PR #163)
- Batch README additions covering multiple features (PR #165)
- `Get-MyIp` utility using `curl.exe` to avoid Invoke-WebRequest alias (PR #169)

### Fixed
- PS profile writer: strips and re-injects profile block instead of skipping (PR #145)
- Dual PS profile paths: write to both PS 5.1 and PS 7+ locations with robust alias registration (PR #146)
- `Install-GitHook` rename, removed unused `gitDir`, restored PSVersion guards (PR #133)
- Hotfix PR #130 regressions: PS 5.1 crash + PSScriptAnalyzer warnings (PR #134)
- Stale PS variable guard test updated to check PSVersion pattern (PR #136)

### Changed
- Branch isolation rule codified: always fork from develop HEAD (PR #129)
- CONTRIBUTING updated with PowerShell 5.x compatibility checklist (PR #119)

## [0.6.0] - 2026-04-18 -- Sprint 6: Tools and CI hardening

### Added
- Vim install via winget on Windows
- Tmux added to system prerequisites
- `va` alias to edit `~/.aliases` in vim
- GitHub issue templates
- Missing aliases added to PowerShell profile
- PS 5.1 validation CI job on Windows runner
- Global tool install in Windows and Linux setup
- Windows regression tests: PS5 compat, profile idempotency, Copilot CLI install
- Direct-push-to-main override policy documented

### Fixed
- Copilot CLI: remove conflicting `gh` alias before extension install (PR #63)
- Copilot CLI: standalone binary install via official script (PRs #73, #78, #80, #82)
- Dotfiles: append managed block to existing `.zshrc`/`.bashrc` (PR #65)
- Line endings: `eol=lf` rules for shell scripts + enforce LF for shell dotfiles (PRs #66, #89, #90)
- Shell: merge stderr into stdout for ordered output in piped environments (PR #70)
- Devcontainer: strip CRLF from `.sh` files on container create (PR #71)
- `sb`/`sz` aliases guarded to their respective shells (PR #93)
- Em-dash in root `setup.ps1` replaced; PATH refreshed after vim install (PR #126)
- `Test-Path` variable guards for PS 6+ auto-vars in `setup.ps1` (PR #130)

### Changed
- Sprint wrap: ban squash merges in favor of regular merge commits
- Removed log/orchestration-log from git tracking

## [0.5.0] - 2026-04-08 -- Sprint 5: Process stabilization

### Added
- Worktree isolation documentation for parallel agent runs (PR #58)
- Agent timeout policy to prevent stalled loops (PR #61)
- `enforce_admins` branch protection decision documented (PR #60)
- Devcontainer: set git identity from env vars on postCreate (PR #49)
- Sprint 5 review cycle completion log (PR #62)

### Removed
- `ps.tar.gz` binary artifact purged from repo; `.gitignore` updated (PR #59)

## [0.4.0] - 2026-04-07 -- Sprint 4: Branch protection and testing

### Added
- Branch protection enabled on `develop` with documented merge gates
- Approval gate enforced and documented
- Regression test for `Remove-CustomItem` multi-argument behavior
- Test coverage for `create_tmux()` session detection logic
- `uv` replaces `pip` for Python tooling in devcontainer

### Fixed
- `create_tmux()`: named session check corrected, dead variable removed (PR #39)
- `Remove-CustomItem`: silent data loss fixed by accepting `string[]` param (PR #40)

## [0.3.0] - 2026-04-07 -- Sprint 3: Dotfiles and shell configuration

### Added
- `.vimrc` template wired into `install.sh` (PR #33)
- Missing aliases and tmux functions added to dotfiles (PR #34)
- Owner shortcuts added to Windows PowerShell profile setup (PR #35)

### Changed
- Example dotfiles consolidated into `examples/` folder (PR #36)

## [0.2.0] - 2026-04-07 -- Sprint 2: CI and initial fixes

### Added
- Idempotency test suite (PR #26)
- Auto-connect: prompt for GitHub auth during setup (PR #27)
- Sprint 1 follow-up action items documented (PR #31)

### Fixed
- PSScriptAnalyzer violations resolved (PR #30)

## [0.1.0] - 2026-04-07 -- Sprint 1: Foundation

### Added
- OS detection and script entry point architecture (PR #17)
- Core setup script for Windows (PowerShell) (PR #23)
- Core setup script for Linux/macOS (Bash) (PR #24)
- Dev Container and Codespace post-create setup (PR #21)
- GitHub Actions workflow for script validation (PR #20)
- README documentation (PR #19)
- Dotfile templates (PR #18)
- Shell shortcuts and aliases (PR #22)
