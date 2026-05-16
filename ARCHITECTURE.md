# Architecture: dev-setup

> **Owner:** Mickey (Lead) — Issue #3  
> **Last updated:** 2026-04-07

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
├── setup.sh                        # Entry point — Unix (Linux / macOS / WSL)
├── setup.ps1                       # Entry point — Windows (PowerShell)
├── ARCHITECTURE.md                 # This file
├── CHANGELOG.md                    # Keep-a-Changelog format
├── CONTRIBUTING.md                 # Contribution guide
├── README.md                       # Project overview and quick start
│
├── scripts/
│   ├── linux/
│   │   ├── setup.sh               # Core Linux/macOS/WSL installer (Donald)
│   │   └── tools/                  # Individual tool scripts, run by core
│   │       ├── auth.sh            # GitHub CLI authentication (interactive)
│   │       ├── copilot-cli.sh     # Install GitHub Copilot CLI
│   │       ├── gh.sh             # Install GitHub CLI
│   │       ├── nvm.sh            # Install nvm + Node LTS
│   │       ├── squad-cli.sh      # Install squad-cli (npm)
│   │       ├── uv.sh             # Install uv Python package manager
│   │       └── zsh.sh            # Install zsh + set as default shell
│   └── windows/
│       ├── setup.ps1              # Orchestrator — dot-sources tool scripts below
│       └── tools/                  # Per-tool install scripts (PR #195 split)
│           ├── copilot.ps1        # GitHub Copilot CLI
│           ├── gh.ps1            # GitHub CLI
│           ├── git.ps1           # Git configuration
│           ├── nvm.ps1           # nvm + Node LTS
│           ├── profile.ps1       # PowerShell profile injection
│           ├── psmux.ps1         # psmux terminal multiplexer
│           ├── squad-cli.ps1     # squad-cli (npm)
│           ├── uv.ps1            # uv Python package manager
│           └── vim.ps1           # Vim editor
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
├── hooks/
│   ├── commit-msg                 # Enforce Conventional Commits format
│   ├── pre-commit                 # Shellcheck on staged .sh files
│   └── pre-push                   # Block pushes to main; advisory linting
│
├── tests/                          # Validation tests
│   ├── README.md                  # Test documentation
│   ├── test_aliases.sh            # Alias loading tests (bash)
│   ├── test_git_hooks.ps1         # Git hook tests (PowerShell)
│   ├── test_idempotency.sh        # Idempotency tests (bash)
│   ├── test_remove_custom_item.ps1 # Custom item removal tests (PowerShell)
│   └── test_windows_setup.ps1     # Windows setup tests (PowerShell)
│
├── .devcontainer/
│   ├── devcontainer.json          # Dev Container / Codespace config
│   └── README.md                  # Dev container documentation
│
├── .github/
│   └── workflows/                  # CI and squad automation (Chip)
│       ├── squad-heartbeat.yml
│       ├── squad-issue-assign.yml
│       ├── squad-triage.yml
│       ├── sync-squad-labels.yml
│       └── validate.yml           # Main CI validation
│
└── .squad/                         # Internal squad coordination (not shipped)
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

`scripts\windows\setup.ps1` is a ~75-line orchestrator that dot-sources individual tool scripts from `scripts\windows\tools\` (split from a monolith in PR #195).

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

## Team Ownership Map

| Path | Owner | Issue(s) |
|------|-------|----------|
| `setup.sh` (root) | Mickey | #3 |
| `setup.ps1` (root) | Mickey | #3 |
| `scripts/linux/setup.sh` | Donald | #1 |
| `scripts/linux/tools/auth.sh` | Donald | #9 |
| `scripts/linux/tools/zsh.sh` | Donald | #4 |
| `scripts/linux/tools/uv.sh` | Donald | #5 |
| `scripts/linux/tools/nvm.sh` | Donald | #6 |
| `scripts/linux/tools/gh.sh` | Donald | #7 |
| `scripts/linux/tools/copilot-cli.sh` | Donald | #7 |
| `scripts/linux/tools/squad-cli.sh` | Donald | — |
| `scripts/windows/setup.ps1` | Goofy | #2 |
| `scripts/windows/tools/` | Goofy | #195 |
| `hooks/pre-commit` | Goofy | #138 |
| `hooks/commit-msg` | Goofy | #138 |
| `hooks/pre-push` | Goofy | #138, #147 |
| `tests/` | Chip | — |
| `config/dotfiles/` | Pluto | #8, #10, #11 |
| `.devcontainer/` | Chip | — |
| `.github/workflows/` | Chip | #12, #13 |
