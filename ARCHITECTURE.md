# Architecture: dev-setup

> **Last updated:** 2026-08-09

---

## Project Goal

`dev-setup` provides a single-command, idempotent developer environment setup for:

- GitHub Codespaces
- Dev Containers
- Fresh Linux, macOS, or Windows machines

Run `bash setup.sh` (Unix) or `powershell -File setup.ps1` (Windows) and walk away. Every tool this project installs is safe to re-install -- the scripts check first and skip if already present.

---

## File Structure

```
dev-setup/
|---- setup.sh                        # Entry point -- Unix (Linux / macOS / WSL); thin router
|---- setup.ps1                       # Entry point -- Windows (PowerShell); thin router
|---- .tool-versions                  # asdf-style pinned versions (node, nvm, uv, gh, copilot-cli)
|---- .gitattributes                  # eol=lf for *.sh / *.md / *.yml; eol=crlf for *.ps1 / *.psm1 / *.psd1
|---- ARCHITECTURE.md                 # This file
|---- CHANGELOG.md                    # Keep-a-Changelog format
|---- CONTRIBUTING.md                 # Contribution guide
|---- README.md                       # Project overview and quick start
|
|---- scripts/
|   |---- lib/                        # Cross-platform shared libraries (PS + sh)
|   |   |---- Read-ToolVersion.ps1   # Get-ToolVersion -Name X -- reads pin from .tool-versions
|   |   `---- read-tool-version.sh   # Same contract for POSIX shells (prints version to stdout)
|   |
|   |---- linux/
|   |   |---- setup.sh               # Core Linux/macOS/WSL installer -- runs tools in order
|   |   |---- uninstall.sh           # Idempotent reverse of the installer
|   |   |---- lib/
|   |   |   |---- log.sh             # Shared log_info / log_ok / log_warn / log_error helpers
|   |   |   `---- tui.sh             # Bash 3.2+ interactive picker
|   |   `---- tools/                  # Per-tool installers (sourced by core in dependency order)
|   |       |---- auth.sh            # GitHub CLI authentication (interactive)
|   |       |---- copilot-cli.sh     # Install GitHub Copilot CLI (pin from .tool-versions)
|   |       |---- gh.sh              # Install GitHub CLI (pin from .tool-versions)
|   |       |---- nvm.sh             # Install nvm + Node (pin from .tool-versions)
|   |       |---- uv.sh              # Install uv Python package manager (pin from .tool-versions)
|   |       `---- zsh.sh             # Install zsh + set as default shell
|   |
|   `---- windows/
|       |---- setup.ps1              # Orchestrator -- dot-sources lib + tool modules below
|       |---- uninstall.ps1          # Idempotent reverse of the installer
|       |---- lib/
|       |   |---- logging.ps1        # Write-Info / Write-Ok / Write-Warn / Write-Err + Assert-LastExit
|       |   |---- path.ps1           # Refresh-SessionPath -- re-reads Machine+User PATH from registry
|       |   `---- tui.ps1            # PS 5.1-safe ASCII picker + ordered resolver
|       `---- tools/                  # Per-tool installer modules
|           |---- auth.ps1           # GitHub CLI authentication (interactive)
|           |---- copilot.ps1        # GitHub Copilot CLI (pin from .tool-versions)
|           |---- dotfiles.ps1       # Apply config/dotfiles/ on Windows
|           |---- gh.ps1             # GitHub CLI (pin from .tool-versions)
|           |---- git.ps1            # Git configuration
|           |---- nvm.ps1            # nvm-windows + Node (pin from .tool-versions)
|           |---- profile.ps1        # PowerShell profile injection (PS 5.1 + PS 7+ paths)
|           |---- psmux.ps1          # psmux terminal multiplexer (Windows tmux alias)
|           |---- uv.ps1             # uv Python package manager (pin from .tool-versions)
|           `---- vim.ps1            # Vim editor
|
|---- config/
|   `---- dotfiles/                   # Dotfile templates
|       |---- .aliases               # Shell aliases (git, dev, utility)
|       |---- .editorconfig          # Editor formatting rules
|       |---- .gitconfig.template    # Git config template
|       |---- .npmrc.template        # npm config template
|       |---- .vimrc                 # Vim configuration
|       |---- .zshrc.template        # Zsh config template
|       |---- install.sh             # Dotfile installer script
|       `---- README.md              # Documents each dotfile and install behaviour
|
|---- hooks/                          # Git hooks; auto-wired via `git config core.hooksPath hooks`
|   |---- pre-commit                 # Branch ancestry + ASCII guard + shellcheck
|   |---- prepare-commit-msg         # Rewrite auto-merge/revert messages into Conventional Commits form
|   |---- commit-msg                 # Enforce Conventional Commits format (hard reject on non-conforming)
|   `---- pre-push                   # Block direct pushes to main; advisory shellcheck + PSScriptAnalyzer
|
|---- tests/                          # Validation tests
|   |---- README.md                  # Test documentation
|   |---- test_alias_parity.sh       # Linux/Windows alias parity test
|   |---- test_aliases.sh            # Alias loading tests (bash)
|   |---- test_git_hooks.ps1         # Git hook tests (PowerShell)
|   |---- test_idempotency.sh        # Idempotency tests (bash)
|   |---- test_nvm_bootstrap.sh      # nvm bootstrap tests
|   |---- test_precommit_hygiene.sh  # pre-commit hygiene checks (ancestry, ASCII, rogue-path)
|   |---- test_remove_custom_item.ps1 # Custom item removal tests (PowerShell)
|   |---- test_setup_flags.sh        # Bash selection flags + interactive guards
|   |---- test_setup_flags_pwsh.ps1  # PowerShell selection flags + interactive guards
|   |---- test_shared_logging.sh     # scripts/linux/lib/log.sh contract tests
|   |---- test_tool_versions.sh      # .tool-versions parser + Get-ToolVersion contract tests
|   |---- test_tui_bash.sh           # Bash picker + ordered selection tests
|   |---- test_tui_pwsh.ps1          # PowerShell picker + resolver tests
|   `---- test_windows_setup.ps1     # Windows setup tests (PowerShell)
|
|---- .devcontainer/
|   |---- devcontainer.json          # Dev Container / Codespace config
|   `---- README.md                  # Dev container documentation
|
|---- .github/
|   `---- workflows/                  # CI workflows
|       |---- validate.yml           # Main CI validation (6 jobs)
|       |---- e2e-install.yml        # E2E smoke test on fresh runners (PR + nightly cron + summary)
|       `---- sprint-end-labels.yml  # Sprint label automation
|
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
uname -s output          -> Platform label
-----------------------------------------------------
Linux + /proc/version    -> "wsl"    (Windows Subsystem for Linux)
  contains "microsoft"
Linux (otherwise)        -> "linux"
Darwin                   -> "macos"
CYGWIN* / MINGW* / MSYS* -> "windows-compat" (warn + try linux path)
*                        -> "unknown" (error + exit 1)
```

**WSL is treated as Linux.** The root `setup.sh` routes WSL to `scripts/linux/setup.sh`, not to the Windows path. This is intentional: WSL users have a full Linux environment and benefit from the same tooling as native Linux.

### Windows (`setup.ps1`)

Uses PowerShell's built-in `$IsWindows`, `$IsLinux`, `$IsMacOS` booleans. If PowerShell is running inside WSL (edge case), it routes to the Windows installer with a warning.

---

## Tool Selection Architecture

The public picker contract, including invocation, controls, headless behavior, flag precedence,
and confirm/cancel results, is documented in the
[README interactive picker section](./README.md#interactive-tool-picker).

Internally, selection is separated from installation:

1. `scripts/linux/setup.sh` and `scripts/windows/setup.ps1` own argument handling, interactive
   eligibility, validation, and final dispatch.
2. `scripts/linux/lib/tui.sh` and `scripts/windows/lib/tui.ps1` own menu state, rendering, and key
   handling. They return selected tool names but never install tools.
3. The selected names flow through the same ordered resolver used by `--only` / `-Only`.
4. The resolver iterates the default-tool sequence first, then appends selected opt-in tools
   alphabetically. Menu display order, user input order, and flag input order cannot reorder
   dependency-sensitive defaults.
5. Cancellation or an empty confirmed selection exits before dispatch.

The default arrays are the authoritative install-order definitions. A tool module that is
available but absent from the default array remains opt-in and is never added to a no-argument
headless run.

---

## Script Conventions

Shared helpers live in dedicated `lib/` directories. Tool scripts **load** them rather than redefining or copy-pasting. Source of truth:

| File                                 | Purpose                                                                                  | Loaded by                                    |
|--------------------------------------|------------------------------------------------------------------------------------------|----------------------------------------------|
| `scripts/linux/lib/log.sh`           | `log_info`, `log_ok`, `log_warn`, `log_error`                                            | `setup.sh` and every `tools/*.sh`            |
| `scripts/linux/lib/tui.sh`           | Bash 3.2+ interactive picker and menu state                                               | `scripts/linux/setup.sh`                     |
| `scripts/windows/lib/logging.ps1`    | `Write-Info`, `Write-Ok`, `Write-Warn`, `Write-Err`, `Assert-LastExit`                   | `setup.ps1` and every `tools/*.ps1`          |
| `scripts/windows/lib/path.ps1`       | `Refresh-SessionPath` (re-reads Machine + User PATH from the registry into the session) | `setup.ps1` and any tool that mutates PATH   |
| `scripts/windows/lib/tui.ps1`        | PS 5.1-safe ASCII picker and `Resolve-FinalToolset`                                      | `scripts/windows/setup.ps1`                  |
| `scripts/lib/read-tool-version.sh`   | POSIX parser for `.tool-versions` (prints the pinned version to stdout)                  | Any `tools/*.sh` that needs a pinned version |
| `scripts/lib/Read-ToolVersion.ps1`   | PowerShell `Get-ToolVersion -Name <tool>` (returns the pinned version)                   | Any `tools/*.ps1` that needs a pinned version |

**Rule:** New helpers go in the appropriate `lib/` directory. Do not copy helper definitions into `setup.sh`, `setup.ps1`, or individual tool scripts.

### Loading helpers

**Bash** uses POSIX `source` (`.`). At the top of `setup.sh` or any `tools/*.sh`, after the safety flags:

```bash
# From scripts/linux/setup.sh (lib is one level down):
. "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"
. "$(dirname "${BASH_SOURCE[0]}")/lib/tui.sh"

# From scripts/linux/tools/<tool>.sh (lib is one level up):
. "$(dirname "${BASH_SOURCE[0]}")/../lib/log.sh"
```

Note that `setup.sh` runs each `tools/*.sh` via `bash <script>` (a subshell), so every tool script must re-source `lib/log.sh` itself; the parent scope is not inherited. The TUI library is orchestrator-only and is not loaded by tool installers.

**PowerShell** uses dot-sourcing (`.`). At the top of `setup.ps1` or any `tools/*.ps1`, after `Set-StrictMode` / `$ErrorActionPreference`:

```powershell
# From scripts/windows/setup.ps1 (lib is alongside):
. "$PSScriptRoot\lib\logging.ps1"
. "$PSScriptRoot\lib\path.ps1"
. "$PSScriptRoot\lib\tui.ps1"

# From scripts/windows/tools/<tool>.ps1 (lib is one level up):
. "$PSScriptRoot\..\lib\logging.ps1"
```

`$PSScriptRoot` is the directory of the currently-executing file. Unlike the bash path, `setup.ps1` **dot-sources** each `tools/*.ps1`, so tool functions (`Install-Nvm`, `Install-GhCli`, ...) live in the parent scope and are invoked through `$ToolRegistry`. Tool scripts still re-dot-source any `lib/` files they need so they are also runnable standalone. The TUI library is orchestrator-only.

### Reading pinned versions from `.tool-versions`

`.tool-versions` is the single source of truth for tool versions (see "Tool Version Pinning" below). Tool scripts must read pins via the shared parsers in `scripts/lib/`; they must not hard-code versions.

**Bash:** invoke the POSIX script and capture stdout. From `scripts/linux/tools/<tool>.sh`:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PINNED_NODE="$(sh "${SCRIPT_DIR}/../../lib/read-tool-version.sh" nodejs)"
```

The parser walks up two levels to find the repo root, so the path from `scripts/linux/tools/` is `../../lib/read-tool-version.sh`. It exits non-zero if the tool is missing or `.tool-versions` is not found; `set -euo pipefail` will surface either.

**PowerShell:** dot-source the parser, then call `Get-ToolVersion`. From `scripts/windows/tools/<tool>.ps1`:

```powershell
$libDir = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'lib'
. (Join-Path $libDir 'Read-ToolVersion.ps1')
$pinnedNode = Get-ToolVersion -Name 'nodejs'
```

Two `Split-Path -Parent` calls climb `tools/ -> windows/ -> scripts/`, then `lib` reaches the shared parser. `Get-ToolVersion` throws on missing tool or missing `.tool-versions`, which surfaces under `$ErrorActionPreference = 'Stop'`.

Reference implementations: `scripts/linux/tools/nvm.sh` and `scripts/windows/tools/nvm.ps1`.

### Bash (`scripts/linux/`)

| Convention | Rule |
|------------|------|
| Shebang | `#!/usr/bin/env bash` |
| Safety flags | `set -euo pipefail` at top of every script |
| Idempotency | Check `command -v <tool>` before installing; skip if present |
| Logging | Source `scripts/linux/lib/log.sh`; call `log_info`, `log_ok`, `log_warn`, `log_error` |
| Version pinning | Read from `.tool-versions` via `sh scripts/lib/read-tool-version.sh <tool>`; never hard-code versions |
| Sourcing | `setup.sh` runs each `tools/*.sh` via `bash <script>` (subshell); tool scripts re-source `lib/log.sh` themselves |
| Exit codes | `exit 0` on success or skip, `exit 1` on unrecoverable error |

### PowerShell (`scripts/windows/`)

| Convention | Rule |
|------------|------|
| Safety | `Set-StrictMode -Version Latest` + `$ErrorActionPreference = 'Stop'` |
| Idempotency | `Get-Command <tool> -ErrorAction SilentlyContinue` before installing |
| Logging | Dot-source `scripts/windows/lib/logging.ps1`; call `Write-Info`, `Write-Ok`, `Write-Warn`, `Write-Err` |
| Exit-code discipline | After any external install, call `Assert-LastExit -ToolName <name>` (use `-AllowedExitCodes` for cases like winget `ALREADY_INSTALLED`) |
| PATH refresh | After an install mutates PATH, dot-source `scripts/windows/lib/path.ps1` and call `Refresh-SessionPath` so `node`, `uv`, `gh`, etc. become callable in the same session |
| Version pinning | Read from `.tool-versions` via `Get-ToolVersion` (dot-source `scripts/lib/Read-ToolVersion.ps1`); never hard-code versions |
| Install method | Prefer `winget`; fall back to `scoop` or direct download (see `nvm.ps1` for the portable-zip pattern) |
| Sourcing | `setup.ps1` dot-sources each `tools/*.ps1`; tool functions live in the parent scope and are invoked by name. Tool scripts re-dot-source their own `lib/` files so they remain runnable standalone. |
| Profile injection | `Write-PowerShellProfile` writes aliases to **both** PS 5.1 (`Documents\WindowsPowerShell\`) and PS 7+ (`Documents\PowerShell\`) paths; sentinel strip+re-inject makes it idempotent |
| Alias registration | All `Set-Alias` calls use `-Force -Scope Global` so aliases work in the current session immediately |

---

## How to Add a New Tool (Linux/macOS)

1. **Create `scripts/linux/tools/<toolname>.sh`**

   ```bash
   #!/usr/bin/env bash
   # scripts/linux/tools/<toolname>.sh -- Install <toolname>
   set -euo pipefail

   log_info()  { printf '\033[0;34m[INFO]\033[0m  %s\n' "$*"; }
   log_ok()    { printf '\033[0;32m[OK]\033[0m    %s\n' "$*"; }

   if command -v <toolname> &>/dev/null; then
     log_ok "<toolname> already installed: $(<toolname> --version)"
     exit 0
   fi

   # Install logic here
   ```

2. **Decide whether the tool is default-on or opt-in**

   Adding the script makes its basename available to the picker and `--only`. To install it by
   default, also add `"<toolname>"` to `DEFAULT_TOOLS` in `scripts/linux/setup.sh` at the correct
   dependency position. Leaving it out keeps the tool opt-in.

3. **Create a companion GitHub issue** if it's a new tool install.

---

## How to Add a New Platform

1. Create a directory under `scripts/<platform>/`
2. Create a `setup.sh` (or `setup.ps1`) in that directory -- this is the platform's core installer
3. Add a detection branch in the root `setup.sh` and/or `setup.ps1`
4. Document the platform in this file

---

## Dependency Order

The default Linux/macOS/WSL tools run in this order (defined by `DEFAULT_TOOLS` in
`scripts/linux/setup.sh`):

```
prereqs -> zsh -> uv -> nvm -> gh -> auth -> copilot-cli -> squad-cli -> dotfiles -> git-hook
```

`copilot-cli` depends on `gh` being installed and (ideally) authenticated. The `auth` script handles interactive GitHub CLI authentication.
Available scripts not listed in `DEFAULT_TOOLS` are opt-in. When selected, they are appended
alphabetically after selected defaults.

### Windows orchestrator chain

The Windows orchestrator `scripts/windows/setup.ps1` dot-sources its shared libraries and per-tool
modules, then maps public tool names to installer functions in `$ToolRegistry`. Dot-source order
does **not** drive dependencies. `$DefaultTools` is the authoritative default order,
`Resolve-FinalToolset` filters that order, and `Main` dispatches the result through the registry.
The default chain is:

```
winget-check -> git -> uv -> nvm -> gh -> auth -> vim -> psmux -> copilot -> squad-cli -> dotfiles -> profile -> git-hook
```

Mapped to registry functions and the `tools/*.ps1` module that defines each:

| # | Registry function | Source module | Mirrors Linux step |
|---|-------------------|---------------|--------------------|
| 1 | `Invoke-WingetGate`        | `tools/winget-check.ps1` | `tools/prereqs.sh` |
| 2 | `Install-Git`              | `tools/git.ps1`          | (package prerequisite) |
| 3 | `Install-Uv`               | `tools/uv.ps1`           | `tools/uv.sh` |
| 4 | `Install-Nvm`              | `tools/nvm.ps1`          | `tools/nvm.sh` |
| 5 | `Install-GhCli`            | `tools/gh.ps1`           | `tools/gh.sh` |
| 6 | `Invoke-GhAuth`            | `tools/auth.ps1`         | `tools/auth.sh` |
| 7 | `Install-Vim`              | `tools/vim.ps1`          | (platform addition) |
| 8 | `Install-Psmux`            | `tools/psmux.ps1`        | (tmux equivalent) |
| 9 | `Install-CopilotCli`       | `tools/copilot.ps1`      | `tools/copilot-cli.sh` |
| 10 | `Install-SquadCli`        | `tools/squad-cli.ps1`    | `tools/squad-cli.sh` |
| 11 | `Install-Dotfiles`        | `tools/dotfiles.ps1`     | `tools/dotfiles.sh` |
| 12 | `Write-PowerShellProfile` | `tools/profile.ps1`      | (PowerShell profile finalizer) |
| 13 | `Install-GitHook`         | `tools/git-hook.ps1`     | `tools/git-hook.sh` |

Cross-platform invariants preserved from the Linux chain above:

- `auth` (interactive `gh auth login`) runs after `gh` so the CLI is on PATH when the prompt fires.
- `copilot` runs after `auth` so the install can detect an authenticated `gh` session.

Windows-specific ordering notes:

- `winget-check` runs first, then `git` -- downstream steps rely on the package manager or git.
- `vim` and `psmux` are explicit `winget` installs because Windows has no equivalent pre-installed editor/multiplexer.
- `dotfiles` + `profile` are Windows-specific finalizers: the Linux side rolls equivalent shell-rc work into `tools/zsh.sh` plus `config/dotfiles/install.sh`, but Windows needs a discrete PowerShell profile injection step (PS 5.1 + PS 7+ profile paths) after the dotfile templates are applied.
- `git-hook` runs last so `core.hooksPath=hooks` is set only after the working tree is in its final state.
- Registry entries absent from `$DefaultTools` are opt-in and are appended alphabetically when selected.

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

- `scripts/lib/Read-ToolVersion.ps1` -- exposes `Get-ToolVersion -Name <toolname>` (PowerShell)
- `scripts/lib/read-tool-version.sh` -- same contract for POSIX shells (prints to stdout)

Currently pinned: `nodejs`, `nvm`, `nvm-windows`, `uv`, `copilot-cli`, `gh`. Tool installers (e.g. `scripts/windows/tools/nvm.ps1`, `scripts/linux/tools/uv.sh`) call the library at install time so version bumps are a single-file edit.

---

## Git Hooks

Hooks live in [`hooks/`](./hooks) and are wired automatically by the installers via `git config core.hooksPath hooks` (no manual install step). Four hooks ship today:

| Hook | Role |
|------|------|
| `pre-commit` | Branch-ancestry guard (feature branches must descend from `develop`), ASCII-only enforcement for staged `*.ps1`, refusal to commit on `develop`/`main`/`master`, shellcheck on staged `*.sh` |
| `prepare-commit-msg` | Rewrites git auto-generated `Merge ...` and `Revert "..."` messages into Conventional Commits form so `commit-msg` accepts them |
| `commit-msg` | Enforces Conventional Commits format (`type(scope): description`). Hard reject on non-conforming. |
| `pre-push` | Blocks direct pushes to `main`; runs shellcheck on changed `*.sh` (advisory) and PSScriptAnalyzer on changed `*.ps1` (advisory) |

---

## CI Workflows

All workflows live in [`.github/workflows/`](./.github/workflows).

### `validate.yml` -- main CI gate (6 jobs)

| Job | Runner | Purpose |
|-----|--------|---------|
| `validate-linux` | `ubuntu-latest` | Installer, idempotency, aliases, tool versions, and Bash picker tests |
| `validate-macos` | `macos-latest` | Linux-shaped validation plus Bash 3.2 picker fallback coverage |
| `lint-shell-scripts` | `ubuntu-latest` | ShellCheck plus Bash flag, guard, and help-contract tests |
| `lint-powershell` | `ubuntu-latest` (pwsh) | PSScriptAnalyzer across the Windows setup and TUI scripts |
| `validate-powershell` | `windows-latest` | Windows regressions plus picker/resolver tests under PowerShell 7 |
| `validate-ps51` | `windows-latest` | Syntax, PSScriptAnalyzer, setup flags, and picker/resolver tests under **PS 5.1** |

### `e2e-install.yml` -- end-to-end smoke test (4 jobs, PR + nightly cron)

| Job | Runner | Purpose |
|-----|--------|---------|
| `e2e-linux` | `ubuntu-latest` | Run `setup.sh` on a fresh runner; assert every tool is reachable from a login shell |
| `e2e-macos` | `macos-latest` | Same shape as `e2e-linux` |
| `e2e-windows` | `windows-latest` | Run `setup.ps1`; PowerShell + winget path |
| `summary` | `ubuntu-latest` | Aggregates the three platform results (`needs: [...]`, `if: always()`) and fails the workflow if any platform failed |

Initially `continue-on-error: true` per platform job; the `summary` job is the single fail-gate. Triggers: `pull_request`, nightly `cron: 0 4 * * *`, and `workflow_dispatch`.
