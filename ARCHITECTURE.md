# Architecture: dev-setup

> **Owner:** Mickey (Lead) — Issue #3  
> **Last updated:** 2026-05-19 (Sprint 11 (formerly Sprint T) refresh — closes #229)

---

## Project Goal

`dev-setup` provides a single-command, idempotent developer environment setup for:

- GitHub Codespaces
- Dev Containers
- Fresh Linux, macOS, or Windows machines

Run `bash setup.sh` (Unix) or `powershell -File setup.ps1` (Windows) and walk away. Every tool this project installs is safe to re-install — the scripts check first and skip if already present.

---

## File Structure

```
dev-setup/
├── setup.sh                        # Entry point — Unix (Linux / macOS / WSL); thin router
├── setup.ps1                       # Entry point — Windows (PowerShell); thin router
├── .tool-versions                  # asdf-style pinned versions (node, nvm, uv, gh, copilot-cli, squad-cli)
├── .gitattributes                  # eol=lf for *.sh / *.md / *.yml; eol=crlf for *.ps1 / *.psm1 / *.psd1 (#231)
├── ARCHITECTURE.md                 # This file
├── CHANGELOG.md                    # Keep-a-Changelog format
├── CONTRIBUTING.md                 # Contribution guide
├── README.md                       # Project overview and quick start
│
├── scripts/
│   ├── lib/                        # Cross-platform shared libraries (PS + sh)
│   │   ├── Read-ToolVersion.ps1   # Get-ToolVersion -Name X — reads pin from .tool-versions
│   │   └── read-tool-version.sh   # Same contract for POSIX shells (prints version to stdout)
│   │
│   ├── linux/
│   │   ├── setup.sh               # Core Linux/macOS/WSL installer (Donald) — runs tools in order
│   │   ├── uninstall.sh           # Idempotent reverse of the installer
│   │   ├── lib/
│   │   │   └── log.sh             # Shared log_info / log_ok / log_warn / log_error helpers
│   │   └── tools/                  # Per-tool installers (sourced by core in dependency order)
│   │       ├── auth.sh            # GitHub CLI authentication (interactive)
│   │       ├── copilot-cli.sh     # Install GitHub Copilot CLI (pin from .tool-versions)
│   │       ├── gh.sh              # Install GitHub CLI (pin from .tool-versions)
│   │       ├── nvm.sh             # Install nvm + Node (pin from .tool-versions)
│   │       ├── squad-cli.sh       # Install squad-cli (npm; pin from .tool-versions)
│   │       ├── uv.sh              # Install uv Python package manager (pin from .tool-versions)
│   │       └── zsh.sh             # Install zsh + set as default shell
│   │
│   └── windows/
│       ├── setup.ps1              # Orchestrator — dot-sources lib + tool modules below
│       ├── auth.ps1               # GitHub CLI authentication (interactive)
│       ├── uninstall.ps1          # Idempotent reverse of the installer
│       ├── lib/
│       │   ├── logging.ps1        # Write-Info / Write-Ok / Write-Warn / Write-Err + Assert-LastExit
│       │   └── path.ps1           # Refresh-SessionPath — re-reads Machine+User PATH from registry
│       └── tools/                  # Per-tool installers (orchestrator + 10 modules; PR #195 split)
│           ├── copilot.ps1        # GitHub Copilot CLI (pin from .tool-versions)
│           ├── dotfiles.ps1       # Apply config/dotfiles/ on Windows
│           ├── gh.ps1             # GitHub CLI (pin from .tool-versions)
│           ├── git.ps1            # Git configuration
│           ├── nvm.ps1            # nvm-windows + Node (pin from .tool-versions)
│           ├── profile.ps1        # PowerShell profile injection (PS 5.1 + PS 7+ paths)
│           ├── psmux.ps1          # psmux terminal multiplexer (Windows tmux alias)
│           ├── squad-cli.ps1      # squad-cli (npm; pin from .tool-versions)
│           ├── uv.ps1             # uv Python package manager (pin from .tool-versions)
│           └── vim.ps1            # Vim editor
│
├── config/
│   └── dotfiles/                   # Dotfile templates (Pluto #8, #10, #11)
│       ├── .aliases               # Shell aliases (git, dev, utility)
│       ├── .editorconfig          # Editor formatting rules
│       ├── .gitconfig.template    # Git config template
│       ├── .npmrc.template        # npm config template
│       ├── .vimrc                 # Vim configuration
│       ├── .zshrc.template        # Zsh config template
│       ├── install.sh             # Dotfile installer script
│       └── README.md              # Documents each dotfile and install behaviour
│
├── hooks/                          # Git hooks; auto-wired via `git config core.hooksPath hooks`
│   ├── pre-commit                 # Branch ancestry + ASCII *.ps1 guard + .squad path allow-list + shellcheck
│   ├── prepare-commit-msg         # Rewrite auto-merge/revert messages into Conventional Commits form (#212)
│   ├── commit-msg                 # Enforce Conventional Commits format (hard reject on non-conforming)
│   └── pre-push                   # Block direct pushes to main; advisory shellcheck + PSScriptAnalyzer
│
├── tests/                          # Validation tests
│   ├── README.md                  # Test documentation
│   ├── test_alias_parity.sh       # Linux/Windows alias parity test
│   ├── test_aliases.sh            # Alias loading tests (bash)
│   ├── test_git_hooks.ps1         # Git hook tests (PowerShell)
│   ├── test_idempotency.sh        # Idempotency tests (bash)
│   ├── test_nvm_bootstrap.sh      # nvm bootstrap tests
│   ├── test_precommit_hygiene.sh  # pre-commit hygiene checks (ancestry, ASCII, rogue-path)
│   ├── test_remove_custom_item.ps1 # Custom item removal tests (PowerShell)
│   ├── test_shared_logging.sh     # scripts/linux/lib/log.sh contract tests
│   ├── test_tool_versions.sh      # .tool-versions parser + Get-ToolVersion contract tests
│   └── test_windows_setup.ps1     # Windows setup tests (PowerShell)
│
├── .devcontainer/
│   ├── devcontainer.json          # Dev Container / Codespace config
│   └── README.md                  # Dev container documentation
│
├── .github/
│   └── workflows/                  # CI + squad automation (Chip) — see "CI Workflows" below
│       ├── validate.yml           # Main CI validation (6 jobs)
│       ├── e2e-install.yml        # E2E smoke test on fresh runners (PR + nightly cron + summary)
│       ├── squad-heartbeat.yml    # Ralph — reacts to issue/PR events to keep the loop alive
│       ├── squad-history-check.yml # Enforce agent history.md updates on squad:* PRs
│       ├── squad-issue-assign.yml # Trigger work when squad:{member} label applied
│       ├── squad-label-enforce.yml # Mutual exclusivity for managed label namespaces
│       ├── squad-triage.yml       # Triage flow when bare `squad` label applied
│       └── sync-squad-labels.yml  # Sync label set from .squad/team.md roster
│
└── .squad/                         # Squad coordination (most subdirs are not "shipped" via npm; see CONTRIBUTING.md)
    ├── agents/                    # charter.md + history.md per agent (see Squad Roster)
    ├── skills/                    # Reusable SKILL.md library (tool-version-pin, pwsh-lastexitcode, ...)
    ├── decisions/                 # Canonical permanent decision records (committed)
    │   └── inbox/                 # Per-agent decision drafts (gitignored)
    ├── retros/                    # Sprint retrospectives
    ├── templates/                 # loop.md, ceremonies.md, agent + workflow templates
    ├── orchestration-log/         # Per-sprint orchestration logs (union-merge)
    ├── team.md                    # Squad roster definition (drives sync-squad-labels.yml)
    ├── routing.md                 # Issue → agent routing rules
    ├── ceremonies.md              # Sprint ceremony cadence
    └── decisions.md               # Append-only decisions log (union-merge)
```

---

## Entry Points

### Unix: `setup.sh` (repo root)

This is the **only file a Linux/macOS/WSL user needs to know about**. It:

1. Detects the OS via `uname -s` and `/proc/version`
2. Logs what it found
3. Delegates to `scripts/linux/setup.sh`

It does **not** install anything itself. It is a thin router.

```bash
bash setup.sh
# or, after chmod +x:
./setup.sh
```

### Windows: `setup.ps1` (repo root)

The **only file a Windows user needs to know about**. It:

1. Detects the platform via PowerShell's `$IsWindows` / `$IsLinux` / `$IsMacOS`
2. Delegates to `scripts\windows\setup.ps1`

`scripts\windows\setup.ps1` is a small orchestrator that dot-sources shared libraries (`lib\logging.ps1`, `lib\path.ps1`) and per-tool installers from `scripts\windows\tools\` (split from a 451-line monolith in PR #195 into an orchestrator + 10 per-tool modules + a `lib/` of shared helpers).

```powershell
powershell -ExecutionPolicy Bypass -File setup.ps1
```

---

## OS Detection Logic

### Unix (`setup.sh`)

```
uname -s output          → Platform label
─────────────────────────────────────────────────────
Linux + /proc/version    → "wsl"    (Windows Subsystem for Linux)
  contains "microsoft"
Linux (otherwise)        → "linux"
Darwin                   → "macos"
CYGWIN* / MINGW* / MSYS* → "windows-compat" (warn + try linux path)
*                        → "unknown" (error + exit 1)
```

**WSL is treated as Linux.** The root `setup.sh` routes WSL to `scripts/linux/setup.sh`, not to the Windows path. This is intentional: WSL users have a full Linux environment and benefit from the same tooling as native Linux.

### Windows (`setup.ps1`)

Uses PowerShell's built-in `$IsWindows`, `$IsLinux`, `$IsMacOS` booleans. If PowerShell is running inside WSL (edge case), it routes to the Windows installer with a warning.

---

## Script Conventions

### Bash (`scripts/linux/`)

| Convention | Rule |
|------------|------|
| Shebang | `#!/usr/bin/env bash` |
| Safety flags | `set -euo pipefail` at top of every script |
| Idempotency | Check `command -v <tool>` before installing; skip if present |
| Logging | Use `log_info`, `log_ok`, `log_warn`, `log_error` helpers (copy from `setup.sh`) |
| Sourcing | Scripts in `tools/` are run via `bash <script>` from the core installer, not `source` — keeps each script isolated |
| Exit codes | `exit 0` on success or skip, `exit 1` on unrecoverable error |

### PowerShell (`scripts/windows/`)

| Convention | Rule |
|------------|------|
| Safety | `Set-StrictMode -Version Latest` + `$ErrorActionPreference = 'Stop'` |
| Idempotency | `Get-Command <tool> -ErrorAction SilentlyContinue` before installing |
| Logging | Use `Write-Info`, `Write-Ok`, `Write-Warn`, `Write-Err` helpers (copy from `setup.ps1`) |
| Install method | Prefer `winget`; fall back to `scoop` or direct download |
| Profile injection | `Write-PowerShellProfile` writes aliases to **both** PS 5.1 (`Documents\WindowsPowerShell\`) and PS 7+ (`Documents\PowerShell\`) paths; sentinel strip+re-inject makes it idempotent |
| Alias registration | All `Set-Alias` calls use `-Force -Scope Global` so aliases work in the current session immediately |

---

## How to Add a New Tool (Linux/macOS)

1. **Create `scripts/linux/tools/<toolname>.sh`**

   ```bash
   #!/usr/bin/env bash
   # scripts/linux/tools/<toolname>.sh — Install <toolname>
   set -euo pipefail

   log_info()  { printf '\033[0;34m[INFO]\033[0m  %s\n' "$*"; }
   log_ok()    { printf '\033[0;32m[OK]\033[0m    %s\n' "$*"; }

   if command -v <toolname> &>/dev/null; then
     log_ok "<toolname> already installed: $(<toolname> --version)"
     exit 0
   fi

   # Install logic here
   ```

2. **Add a `run_tool "<toolname>"` call in `scripts/linux/setup.sh`**

   ```bash
   run_tool "toolname"
   ```

3. **Create a companion GitHub issue** labeled `squad:donald` (if it's a new tool install).

---

## How to Add a New Platform

1. Create a directory under `scripts/<platform>/`
2. Create a `setup.sh` (or `setup.ps1`) in that directory — this is the platform's core installer
3. Add a detection branch in the root `setup.sh` and/or `setup.ps1`
4. Document the platform in this file

---

## Dependency Order

The tool scripts in `scripts/linux/tools/` must run in this order (enforced by `scripts/linux/setup.sh`):

```
zsh → uv → nvm → gh → auth → copilot-cli → squad-cli
```

`copilot-cli` depends on `gh` being installed and (ideally) authenticated. The `auth` script handles interactive GitHub CLI authentication (issue #9). `squad-cli` depends on `nvm` (Node/npm).

---

## Idempotency Guarantee

Every script in this project must be safe to run multiple times. The pattern is:

```bash
if <already installed check>; then
  log_ok "<tool> already installed"
  exit 0
fi
# install
```

This means running `bash setup.sh` on a fully-configured machine is a no-op.

---

## Tool Version Pinning (`.tool-versions`)

Tool versions are pinned in the repo-root [`.tool-versions`](./.tool-versions) file (asdf-style: `name<space>version`, one per line). Both the Linux and Windows installers read pins through a shared library so the same version is installed across all platforms:

- `scripts/lib/Read-ToolVersion.ps1` — exposes `Get-ToolVersion -Name <toolname>` (PowerShell)
- `scripts/lib/read-tool-version.sh` — same contract for POSIX shells (prints to stdout)

Currently pinned: `nodejs`, `nvm`, `nvm-windows`, `uv`, `copilot-cli`, `squad-cli`, `gh`. Tool installers (e.g. `scripts/windows/tools/nvm.ps1`, `scripts/linux/tools/uv.sh`) call the library at install time so version bumps are a single-file edit. See `.squad/skills/tool-version-pin/SKILL.md` for the pattern.

Companion skill: `.squad/skills/pwsh-lastexitcode/SKILL.md` — the `$LASTEXITCODE = 0` reset pattern required when chaining native commands across pwsh `&` script-call boundaries (CI gating discipline).

---

## Git Hooks

Hooks live in [`hooks/`](./hooks) and are wired automatically by the installers via `git config core.hooksPath hooks` (no manual install step). Four hooks ship today:

| Hook | Role |
|------|------|
| `pre-commit` | Branch-ancestry guard (`squad/*` must descend from `develop`), ASCII-only enforcement for staged `*.ps1`, `.squad/` path allow-list (incl. `decisions/*.md`, `retros/*.md`, and `templates/*.template`), refusal to commit on `develop`/`main`/`master`, shellcheck on staged `*.sh` |
| `prepare-commit-msg` | Rewrites git auto-generated `Merge ...` and `Revert "..."` messages into Conventional Commits form so `commit-msg` accepts them (added in #212) |
| `commit-msg` | Enforces Conventional Commits format (`type(scope): description`). Hard reject on non-conforming. |
| `pre-push` | Blocks direct pushes to `main`; runs shellcheck on changed `*.sh` (advisory) and PSScriptAnalyzer on changed `*.ps1` (advisory) |

The pre-commit allow-list is the canonical source of truth for which paths under `.squad/` may be staged. See `hooks/pre-commit` Check 3 for the full table.

---

## CI Workflows

All workflows live in [`.github/workflows/`](./.github/workflows). Owned by Chip.

### `validate.yml` — main CI gate (6 jobs)

| Job | Runner | Purpose |
|-----|--------|---------|
| `validate-linux` | `ubuntu-latest` | Run `setup.sh`, assert zsh/uv/nvm/node/gh, idempotency re-run, alias unit + parity tests |
| `validate-macos` | `macos-latest` | Same shape as `validate-linux` + tool-version pin tests (added Sprint 10 (formerly Sprint S)) |
| `lint-shell-scripts` | `ubuntu-latest` | shellcheck across `setup.sh`, `scripts/linux/**`, `config/dotfiles/.aliases` |
| `lint-powershell` | `ubuntu-latest` (pwsh) | PSScriptAnalyzer across `setup.ps1` + `scripts/windows/setup.ps1` |
| `validate-powershell` | `windows-latest` | `Remove-CustomItem` regression + git-hooks tests under PS 7 |
| `validate-ps51` | `windows-latest` | Syntax + PSScriptAnalyzer + profile-write + git-hooks tests under **PS 5.1** (Windows stock) |

### `e2e-install.yml` — end-to-end smoke test (4 jobs, PR + nightly cron)

| Job | Runner | Purpose |
|-----|--------|---------|
| `e2e-linux` | `ubuntu-latest` | Run `setup.sh` on a fresh runner; assert every tool is reachable from a login shell; `squad --version` regression for `session persistence may fail` warning (#255) |
| `e2e-macos` | `macos-latest` | Same shape as `e2e-linux` |
| `e2e-windows` | `windows-latest` | Run `setup.ps1`; PowerShell + winget path |
| `summary` | `ubuntu-latest` | Aggregates the three platform results (`needs: [...]`, `if: always()`) and fails the workflow if any platform failed (added in #253) |

Initially `continue-on-error: true` per platform job; the `summary` job is the single fail-gate. Triggers: `pull_request`, nightly `cron: 0 4 * * *`, and `workflow_dispatch`.

### Squad automation (Chip + Ralph)

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `squad-heartbeat.yml` | `issues` (closed/labeled), `pull_request` (closed), manual | Ralph — react to completed work / new squad work to keep the loop alive |
| `squad-history-check.yml` | `pull_request` to `develop`/`main` | Enforce `agents/{name}/history.md` updates when a `squad:*` label is present |
| `squad-issue-assign.yml` | `issues` (labeled with `squad:{member}`) | Drop the "Assigned to {Member}" instructional comment |
| `squad-label-enforce.yml` | `issues` (labeled) | Enforce mutual exclusivity for `go:`, `release:`, `type:`, `priority:` namespaces |
| `squad-triage.yml` | `issues` (labeled `squad`) | Lead-agent triage on bare `squad` label |
| `sync-squad-labels.yml` | push to `.squad/team.md`, manual | Sync GitHub labels to match the roster |

---

## Squad Roster

The squad lives under [`.squad/agents/`](./.squad/agents) — each agent owns a directory with `charter.md` (identity, boundaries, voice) and `history.md` (append-only work log).

**Core engineering agents (own code / tests / config):**

| Agent | Role | Owns |
|-------|------|------|
| Mickey | Lead | Architecture, code review, scope decisions, triage |
| Donald | Linux/macOS engineer | `scripts/linux/`, POSIX tool installers |
| Goofy | Windows engineer | `scripts/windows/`, hooks |
| Chip | Test / CI engineer | `tests/`, `.github/workflows/`, `.devcontainer/` |
| Pluto | Dotfiles & shell config | `config/dotfiles/` |

**Role-based agents (own process / quality / history):**

| Agent | Role | Trigger |
|-------|------|---------|
| Doc | Fact-checker | review/verify/fact-check/audit keywords; writes from a dedicated worktree per sprint (see `.squad/decisions/doc-and-jiminy-automation.md`) |
| Jiminy | Conscience / auditor | post-batch audit gate after multi-agent batches (≥3 agents); enforced by `.squad/templates/loop.md` and `.squad/templates/ceremonies.md` |
| Scribe | History & changelog steward | Sprint wrap fold of `history.md` and `CHANGELOG.md` curation |
| Ralph | Heartbeat | Runs as `squad-heartbeat.yml` workflow on issue/PR events; not a human-facing agent |

Permanent cross-agent decisions live in `.squad/decisions/*.md` (e.g., `doc-and-jiminy-automation.md`, `mickey-architecture-entry-point.md`, `pluto-dotfiles.md`). Drafts land in `.squad/decisions/inbox/` (gitignored) before being promoted.

---

## Team Ownership Map

| Path | Owner | Issue(s) |
|------|-------|----------|
| `setup.sh` (root) | Mickey | #3 |
| `setup.ps1` (root) | Mickey | #3 |
| `.tool-versions` | Mickey | Sprint 10 |
| `scripts/lib/` | Mickey | Sprint 10 |
| `scripts/linux/setup.sh` | Donald | #1 |
| `scripts/linux/lib/log.sh` | Donald | — |
| `scripts/linux/uninstall.sh` | Donald | — |
| `scripts/linux/tools/auth.sh` | Donald | #9 |
| `scripts/linux/tools/zsh.sh` | Donald | #4 |
| `scripts/linux/tools/uv.sh` | Donald | #5 |
| `scripts/linux/tools/nvm.sh` | Donald | #6 |
| `scripts/linux/tools/gh.sh` | Donald | #7 |
| `scripts/linux/tools/copilot-cli.sh` | Donald | #7 |
| `scripts/linux/tools/squad-cli.sh` | Donald | — |
| `scripts/windows/setup.ps1` | Goofy | #2, #195 |
| `scripts/windows/lib/` | Goofy | #195 |
| `scripts/windows/tools/` | Goofy | #195 |
| `scripts/windows/auth.ps1` | Goofy | #2 |
| `scripts/windows/uninstall.ps1` | Goofy | — |
| `hooks/pre-commit` | Goofy | #138 |
| `hooks/prepare-commit-msg` | Goofy | #212 |
| `hooks/commit-msg` | Goofy | #138 |
| `hooks/pre-push` | Goofy | #138, #147 |
| `tests/` | Chip | — |
| `config/dotfiles/` | Pluto | #8, #10, #11 |
| `.devcontainer/` | Chip | — |
| `.github/workflows/` | Chip | #12, #13, #253 |
| `.squad/agents/` | Each agent owns their own directory | — |
| `.squad/skills/` | Authoring agent (Mickey reviews) | — |
| `.squad/decisions/` | Mickey (curator) | — |
