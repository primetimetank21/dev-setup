# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- Windows: session PATH now refreshed after every `winget install` so just-installed binaries (nvm, git, gh, vim, copilot, psmux) resolve immediately without restarting the terminal; preserves session-only PATH entries (e.g., GitHub Actions tool-cache, profile-injected paths) (closes #251)
- Windows: defensive nvm-windows PATH injection after winget install to avoid registry timing race in CI environments (#251)
- Pinned Node.js version bumped from 20.11.0 to 22.11.0 in `.tool-versions` to satisfy `squad-cli` engine requirement (`>=22.5.0`); added `nvm alias default` so fresh shells inherit the pinned version; affects Linux, macOS, and Windows setup paths (fixes #252, related #255)
- E2E install workflow: added Node major version assertion (>=22) to Linux and macOS fresh-shell steps to prevent future regressions (#252)
- CI: Added nvm + Node.js validation step to validate-macos job, aligning with validate-linux (closes #225)
- Pre-commit hook now refuses commits directly on `develop`, `main`, or `master` with a clear error message directing the user to create a feature branch (closes #249)

## [0.8.0] - 2026-05-16

### Added
- Pre-commit hygiene checks: ASCII-only enforcement on staged `.ps1` files, rogue `.squad/` path validation, staged inbox file detection, and branch ancestry verification for squad branches (closes #240)
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
- Shared logging helpers extracted to `scripts/linux/lib/log.sh` and `scripts/windows/lib/logging.ps1` (closes #186)
- Support for `merge` type in commit-msg hook type allowlist (#212)
- `squad-cli` install failure is now a loud error with actionable hints (was silent warning)
- `scripts/linux/tools/nvm.sh` installs pinned Node version from `.tool-versions` (was `--lts`)
- `scripts/linux/tools/nvm.sh` reads nvm version from `.tool-versions` instead of fetching latest
- `scripts/linux/tools/uv.sh` reads uv version from `.tool-versions` instead of fetching latest
- `scripts/linux/tools/copilot-cli.sh` reads copilot-cli version from `.tool-versions`
- `scripts/windows/tools/nvm.ps1` reads nvm version from `.tool-versions`
- Made tmux auto-attach opt-in via `TMUX_AUTOSTART=1` env var (was always-on)
- Refreshed ARCHITECTURE.md and README.md file trees to match current repo layout
- commit-msg no longer needs special-case bypass for merge/revert -- prepare-commit-msg now normalizes them (#212)

### Fixed
- `scripts/windows/tools/nvm.ps1` resolved wrong lib path (one level up instead of two); `Read-ToolVersion.ps1` not found at runtime (closes #221)
- Added runtime assertion in `nvm.ps1` to catch missing lib directory early
- PS 5.1 compat: psmux install skip-with-warning + profile write diagnostics (PR #198)

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
- Vim install via winget on Windows (PR #112)
- Tmux added to system prerequisites (PR #84)
- `va` alias to edit `~/.aliases` in vim (PR #86)
- GitHub issue templates (PR #114)
- Missing aliases added to PowerShell profile (PR #115)
- PS 5.1 validation CI job on Windows runner (PR #116)
- `squad-cli` global install in Windows and Linux setup (PR #118)
- Windows regression tests: PS5 compat, profile idempotency, Copilot CLI install (PR #104)
- Direct-push-to-main override policy documented (PR #117)

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
- Sprint wrap: ban squash merges in favor of regular merge commits (PR #100)
- Removed log/orchestration-log from git tracking (PR #101)

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
- Branch protection enabled on `develop` with documented merge gates (PR #47)
- Mickey approval gate enforced and documented in Ralph spec (PR #48)
- Regression test for `Remove-CustomItem` multi-argument behavior (PR #52)
- Test coverage for `create_tmux()` session detection logic (PR #53)
- `uv` replaces `pip` for Python tooling in devcontainer (PR #50)

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
