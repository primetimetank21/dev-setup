# Architecture: dev-setup

> **Last updated:** 2026-11-21

---

## Project Goal

`dev-setup` provides a single-command, idempotent developer environment setup for:

- GitHub Codespaces
- Dev Containers
- Fresh Linux, macOS, or Windows machines

The entry points resolve a selection and run its steps in dependency order. Interactive terminals can use the picker; unattended runs use explicit flags or defaults. Version-aware skips make repeated setup practical, but configuration steps can still overwrite owned files or refresh profile blocks. Start with the [human overview](README.md), [agent guide](AGENTS.md) or [setup reference](docs/setup.md) as appropriate.

---

## File Structure

```
dev-setup/
|---- setup.sh                        # Entry point -- Unix (Linux / macOS / WSL); thin router
|---- setup.ps1                       # Entry point -- Windows (PowerShell); thin router
|---- .tool-versions                  # asdf-style pinned versions (node, nvm, gh, copilot-cli, pi, herdr)
|---- .gitattributes                  # eol=lf for *.sh / *.md / *.yml; eol=crlf for *.ps1 / *.psm1 / *.psd1
|---- ARCHITECTURE.md                 # This file
|---- CHANGELOG.md                    # Keep-a-Changelog format
|---- CONTRIBUTING.md                 # Contribution guide
|---- README.md                       # Concise human overview and quick start
|---- AGENTS.md                       # Agent source map, constraints and safe checks
|---- docs/                           # Detailed setup and shutdown references
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
|   |   `---- tools/                  # Per-tool installers (executed in dependency order)
|   |       |---- auth.sh            # GitHub CLI authentication (interactive)
|   |       |---- copilot-cli.sh     # Install GitHub Copilot CLI (pin from .tool-versions)
|   |       |---- gh.sh              # Install GitHub CLI (pin from .tool-versions)
|   |       |---- herdr.sh           # Install Herdr (pin from .tool-versions)
|   |       |---- nvm.sh             # Install nvm + Node (pin from .tool-versions)
|   |       |---- pi.sh              # Install pi CLI (pin from .tool-versions)
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
|           |---- herdr.ps1          # Herdr (pin from .tool-versions)
|           |---- nvm.ps1            # nvm-windows + Node (pin from .tool-versions)
|           |---- pi.ps1             # pi CLI (pin from .tool-versions)
|           |---- profile.ps1        # PowerShell profile injection (PS 5.1 + PS 7+ paths)
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
|   |---- pre-commit                 # ASCII guard + protected-branch refusal + shellcheck
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
|   |---- test_precommit_hygiene.sh  # Historical/targeted pre-commit regression cases
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
[setup guide](docs/setup.md#interactive-tool-picker).

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
| Idempotency | For versioned tools, compare the installed version with the pin; skip only when the requested state already holds |
| Logging | Source `scripts/linux/lib/log.sh`; call `log_info`, `log_ok`, `log_warn`, `log_error` |
| Version pinning | Read from `.tool-versions` via `sh scripts/lib/read-tool-version.sh <tool>`; never hard-code versions |
| Sourcing | `setup.sh` runs each `tools/*.sh` via `bash <script>` (subshell); tool scripts re-source `lib/log.sh` themselves |
| Exit codes | `exit 0` on success or skip, `exit 1` on unrecoverable error |

### PowerShell (`scripts/windows/`)

| Convention | Rule |
|------------|------|
| Safety | `Set-StrictMode -Version Latest` + `$ErrorActionPreference = 'Stop'` |
| Idempotency | For versioned tools, compare the installed version with the shared pin before deciding to skip |
| Logging | Dot-source `scripts/windows/lib/logging.ps1`; call `Write-Info`, `Write-Ok`, `Write-Warn`, `Write-Err` |
| Exit-code discipline | After any external install, call `Assert-LastExit -ToolName <name>` (use `-AllowedExitCodes` for cases like winget `ALREADY_INSTALLED`) |
| PATH refresh | After an install mutates PATH, dot-source `scripts/windows/lib/path.ps1` and call `Refresh-SessionPath` so `node`, `gh`, etc. become callable in the same session |
| Version pinning | Read from `.tool-versions` via `Get-ToolVersion` (dot-source `scripts/lib/Read-ToolVersion.ps1`); never hard-code versions |
| Install method | Prefer `winget`; fall back to `scoop` or direct download (see `nvm.ps1` for the portable-zip pattern) |
| Sourcing | `setup.ps1` dot-sources each `tools/*.ps1`; tool functions live in the parent scope and are invoked by name. Tool scripts re-dot-source their own `lib/` files so they remain runnable standalone. |
| Profile injection | `Write-PowerShellProfile` resolves each host's `$PROFILE`, falls back when needed, deduplicates paths and replaces canonical managed blocks. Current writes are ASCII; see configuration cautions in the setup guide |
| Alias registration | Generated profile aliases use `-Force -Scope Global` when the profile is loaded at startup; writing the profile does not activate it in an already-running session |

---

## How to Add a New Tool (Linux/macOS)

1. Add a standalone `scripts/linux/tools/<name>.sh` using the canonical logging library and the [version-aware pinning pattern](CONTRIBUTING.md#tool-version-pin-enforcement). Do not copy logging helpers or use a bare executable-presence guard for a versioned tool.
2. Keep the tool opt-in unless default inclusion is part of the approved change. Add it to `DEFAULT_TOOLS` only at the intended dependency position.
3. For Windows parity, add the module, dot-source it and register it in `$ToolRegistry`; update `$DefaultTools` only when intended. Preserve aliases and canonical ordering.
4. Update selection/failure tests, native CI coverage and default-order fixtures when affected. Check with `bash scripts/dev/regenerate-baseline-fixtures.sh --check`.
5. Update the concise overview or linked setup reference as appropriate. Verify actual `--list` / `-List` output rather than maintaining a duplicate tool registry in prose.

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
prereqs -> zsh -> nvm -> gh -> auth -> copilot-cli -> dotfiles -> git-hook
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
winget-check -> git -> nvm -> gh -> auth -> vim -> copilot -> dotfiles -> profile -> git-hook
```

Mapped to registry functions and the `tools/*.ps1` module that defines each:

| # | Registry function | Source module | Mirrors Linux step |
|---|-------------------|---------------|--------------------|
| 1 | `Invoke-WingetGate`        | `tools/winget-check.ps1` | `tools/prereqs.sh` |
| 2 | `Install-Git`              | `tools/git.ps1`          | (package prerequisite) |
| 3 | `Install-Nvm`              | `tools/nvm.ps1`          | `tools/nvm.sh` |
| 4 | `Install-GhCli`            | `tools/gh.ps1`           | `tools/gh.sh` |
| 5 | `Invoke-GhAuth`            | `tools/auth.ps1`         | `tools/auth.sh` |
| 6 | `Install-Vim`              | `tools/vim.ps1`          | (platform addition) |
| 7 | `Install-CopilotCli`       | `tools/copilot.ps1`      | `tools/copilot-cli.sh` |
| 8 | `Install-Dotfiles`        | `tools/dotfiles.ps1`     | `tools/dotfiles.sh` |
| 9 | `Write-PowerShellProfile` | `tools/profile.ps1`      | (PowerShell profile finalizer) |
| 10 | `Install-GitHook`         | `tools/git-hook.ps1`     | `tools/git-hook.sh` |

Cross-platform invariants preserved from the Linux chain above:

- `auth` (interactive `gh auth login`) runs after `gh` so the CLI is on PATH when the prompt fires.
- `copilot` runs after `auth` so the install can detect an authenticated `gh` session.

Windows-specific ordering notes:

- `winget-check` runs first, then `git` -- downstream steps rely on the package manager or git.
- `vim` is an explicit `winget` install because Windows has no equivalent pre-installed editor.
- `dotfiles` + `profile` are Windows-specific finalizers: the Linux side rolls equivalent shell-rc work into `tools/zsh.sh` plus `config/dotfiles/install.sh`, but Windows needs a discrete PowerShell profile injection step (PS 5.1 + PS 7+ profile paths) after the dotfile templates are applied.
- `git-hook` runs last so `core.hooksPath=hooks` is set only after the working tree is in its final state.
- Registry entries absent from `$DefaultTools` are opt-in and are appended alphabetically when selected.

---

## Idempotency Guarantee

Installers aim to skip work when the requested version/configuration is already present. For versioned tools, compare the installed version with the pin; do not treat a bare `command -v` / `Get-Command` check as sufficient.

Repeatability is **not** a guarantee that a configured machine is a no-op. Dotfile copies may overwrite differing content with bounded backup retention; profile steps update managed configuration. See [configuration and backups](docs/setup.md#configuration-and-backups). Exercise full repeated installations only in CI or a deliberately disposable environment.

---
## Tool Version Pinning (`.tool-versions`)

Tool versions are pinned in the repo-root [`.tool-versions`](./.tool-versions) file (asdf-style: `name<space>version`, one per line). Version-aware Linux and Windows installers read the shared registry through these helpers; package-manager limitations can cause logged drift:

- `scripts/lib/Read-ToolVersion.ps1` -- exposes `Get-ToolVersion -Name <toolname>` (PowerShell)
- `scripts/lib/read-tool-version.sh` -- same contract for POSIX shells (prints to stdout)

Use the registry itself for the current names and values rather than a duplicated version list. The Node installers read the `nodejs` pin. See [version-pin enforcement](CONTRIBUTING.md#tool-version-pin-enforcement) for update/skip behavior and platform constraints.

---

## Git Hooks

The `git-hook` step sets `core.hooksPath=hooks`; it does not make every hook executable. [CONTRIBUTING.md](CONTRIBUTING.md#git-hooks) is the canonical description of actual hook checks, optional-tool skips and the nonexecutable message-rewrite helper. Verify the configured path/modes rather than assuming every shipped file is active.

---

## CI Workflows

Actual triggers, runners and job definitions live in [`.github/workflows/`](.github/workflows/), rather than in a duplicated job-count table.

- [`validate.yml`](.github/workflows/validate.yml) runs on PRs and pushes to `main`/`develop`. It covers Linux/macOS installation, shell and PowerShell lint, Windows regressions, native PowerShell 5.1, and isolated completion on Linux/macOS. Selection, retirement, aliases and non-forwarding shutdown checks are included in the relevant platform jobs.
- [`e2e-install.yml`](.github/workflows/e2e-install.yml) runs platform install smoke tests on PRs, its scheduled run and manual dispatch, with an aggregate result. These jobs modify disposable hosted runners, not a contributor's workstation.
- [`sprint-end-labels.yml`](.github/workflows/sprint-end-labels.yml) is optional maintainer metadata automation. See [label automation](CONTRIBUTING.md#sprint-end-label-automation) before using its write mode.

Native macOS/Bash 3.2 and Windows/PowerShell 5.1 execution remain distinct from Linux parser checks or emulation. [AGENTS.md](AGENTS.md#safe-validation) and [tests/README.md](tests/README.md) identify safe local entry points and the suites that require an isolated machine.
