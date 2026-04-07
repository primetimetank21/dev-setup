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
│
├── scripts/
│   ├── linux/
│   │   ├── setup.sh                # Core Linux/macOS/WSL installer (Donald)
│   │   └── tools/                  # Individual tool scripts, sourced by core
│   │       ├── zsh.sh              # Install zsh + set as default shell (Donald #4)
│   │       ├── uv.sh               # Install uv Python package manager (Donald #5)
│   │       ├── nvm.sh              # Install nvm + Node LTS (Donald #6)
│   │       ├── gh.sh               # Install GitHub CLI (Donald #7)
│   │       └── copilot-cli.sh      # Install GitHub Copilot CLI (Donald #7)
│   └── windows/
│       └── setup.ps1               # Core Windows installer (Goofy #2)
│
├── config/
│   └── dotfiles/                   # Dotfile templates (Pluto #8, #10, #11)
│       └── README.md               # Documents each dotfile and install behaviour
│
├── .github/
│   └── workflows/                  # CI (Chip)
│
├── .squad/                         # Internal squad coordination (not shipped)
│
└── ARCHITECTURE.md                 # This file
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
zsh → uv → nvm → gh → copilot-cli
```

`copilot-cli` depends on `gh` being installed and (ideally) authenticated. The `gh` auth step is handled separately (issue #9) as it requires interactive input.

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
| `scripts/linux/tools/zsh.sh` | Donald | #4 |
| `scripts/linux/tools/uv.sh` | Donald | #5 |
| `scripts/linux/tools/nvm.sh` | Donald | #6 |
| `scripts/linux/tools/gh.sh` | Donald | #7 |
| `scripts/linux/tools/copilot-cli.sh` | Donald | #7 |
| `scripts/windows/setup.ps1` | Goofy | #2 |
| `config/dotfiles/` | Pluto | #8, #10, #11 |
| `.github/workflows/` | Chip | #12, #13 |
