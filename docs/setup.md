# Setup guide

[Back to the overview](../README.md)

Run examples from the repository root. Use the native PowerShell entry point on Windows, not the Git Bash/Cygwin compatibility fallback. Windows examples below assume a session allowed to run scripts; otherwise use `powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1` followed by the shown flags. This bypass is process-scoped, not a permanent execution-policy change.

Some selected installers require administrator privileges or `sudo`, network access and their platform package manager. Review the individual [Unix](../scripts/linux/tools/) or [Windows](../scripts/windows/tools/) step before running it on an existing machine.

## Tool Selection

`setup.sh` and `setup.ps1` share one ordered selection model. In an eligible interactive terminal,
a no-argument run opens the tool picker. In CI, headless sessions, or when selection flags are
provided, setup skips the picker and uses the deterministic flag/default path instead.

### Interactive Tool Picker

Run setup normally to open the picker in an interactive terminal, or request it explicitly:

| Action | Linux / macOS / WSL | Windows |
|--------|---------------------|---------|
| Open when the terminal is interactive | `bash setup.sh` | `.\setup.ps1` |
| Explicitly request the picker | `bash setup.sh --interactive` | `.\setup.ps1 -Interactive` |
| Explicitly suppress the picker | `bash setup.sh --non-interactive` | `.\setup.ps1 -NonInteractive` |

For automation and devcontainers, use `--non-interactive` or
`SETUP_NON_INTERACTIVE=1`; CI auto-detect also suppresses the menu, so it is
never required.

An explicit interactive request still obeys the CI/headless safety checks. The picker is
automatically suppressed when setup detects CI, GitHub Actions, redirected or unavailable
interactive I/O, or no usable interactive console. A suppressed no-argument run installs the
default tools in their defined order.

For an additional non-interactive escape hatch, set `SETUP_NON_INTERACTIVE=1`:

```bash
SETUP_NON_INTERACTIVE=1 bash setup.sh
```

```powershell
$env:SETUP_NON_INTERACTIVE = '1'
.\setup.ps1
```

Picker behavior is consistent across platforms:

- Default tools appear first in dependency order, pre-checked and labeled `(default)`.
- Available opt-in tools follow alphabetically, unchecked and labeled `(opt-in)`.
- Confirming installs the checked tools through the same ordered selection engine used by flags.
- Cancelling exits successfully without installing anything and prints `Install cancelled.`
- Confirming with every item unchecked exits successfully and prints `Nothing selected, exiting.`
- In supported interactive consoles, Quiet Accent uses cyan for headings and focus, green for
  checked markers and confirmations, and yellow for opt-ins, cancellations, and warnings.
  The ASCII markers and labels remain the source of meaning. Styling is suppressed for redirected
  output, `NO_COLOR`, and unsupported terminals (including Bash with `TERM=dumb`).

Controls depend on the shell:

| Environment | Controls |
|-------------|----------|
| Bash 4.2 or newer | Up/Down to move, Space to toggle, `A` to toggle all, Enter to confirm, `Q` or Esc to cancel |
| Bash 3.2 | Enter a tool number to toggle it, `A` to toggle all, Enter on an empty prompt to confirm, `Q` to cancel |
| Windows PowerShell 5.1 or newer | ASCII `[x]` / `[ ]` menu with Up/Down, Space, `A`, Enter, and Esc or `Q` |

For CI and automation, use `--only` / `--skip` or `-Only` / `-Skip`. These flags are the
deterministic interface and take precedence over the picker, even if the interactive flag is also
present.

### Available Flags

| Flag | Linux / macOS / WSL | Windows |
|------|---------------------|---------|
| List available tools, exit (no install) | `--list` | `-List` |
| Print usage, exit | `--help` | `-Help` |
| Install only the named tools | `--only=a,b,c` | `-Only 'a,b,c'` |
| Install all defaults except named tools | `--skip=a,b,c` | `-Skip 'a,b,c'` |
| Request the interactive picker | `--interactive` | `-Interactive` |
| Never show the interactive picker | `--non-interactive` | `-NonInteractive` |

### Linux / macOS / WSL Examples

```bash
# List all selectable tool names
bash setup.sh --list

# Print usage
bash setup.sh --help

# Install only zsh and gh
bash setup.sh --only=zsh,gh

# Install everything except auth and copilot-cli
bash setup.sh --skip=auth,copilot-cli
```

### Windows Examples

```powershell
# List all selectable tool names
.\setup.ps1 -List

# Print usage
.\setup.ps1 -Help

# Install only vim and gh
.\setup.ps1 -Only 'vim,gh'

# Install everything except auth and copilot-cli
.\setup.ps1 -Skip 'auth,copilot-cli'
```

### Caveats

**`--only` / `-Only` does not auto-include prerequisites.** Selecting `--only=nvm` installs
only nvm -- earlier steps (`prereqs`, `zsh`) are not pulled in automatically.
If a tool depends on earlier steps, list all required tools explicitly:

```bash
# Correct: include prereqs before nvm
bash setup.sh --only=prereqs,nvm
```

**`--only` and `--skip` are mutually exclusive.** Combining both flags exits with an error.

**`--list` takes precedence.** If `--list` is passed alongside `--only` or `--skip`, the tool
list is printed and setup exits without installing anything.

Tool names are validated against the available list. An unknown name exits with an error and
prints the available tools. Use `--list` / `-List` to see valid names before running.

## Configuration and Backups

**Do not assume an already-configured machine makes setup a no-op.** Version checks can skip installations, but selected configuration steps may still replace files or refresh managed blocks.

- Unix `dotfiles` can overwrite differing `.gitconfig` and `.npmrc` copies after taking timestamped backups. It creates/retargets `.editorconfig`, `.aliases` and `.vimrc` symlinks, and adds shell-rc wiring.
- Windows `dotfiles` copies `.editorconfig`, `.gitconfig`, `.npmrc` and `_vimrc` into `USERPROFILE`, backing up differing files. The separate `profile` step writes shortcuts to resolved PowerShell profile paths.
- Dotfile backup helpers normally keep the newest **five** timestamped backups; `DOTFILE_BACKUP_KEEP` changes that retention. Keep an independent copy of personal configuration if it must not be lost.
- Windows profile updates currently write ASCII. Back up and inspect personalized/non-ASCII profiles before choosing that step; arbitrary Unicode preservation is not guaranteed.
- Unix links point into this checkout. Updating or deleting the checkout can affect configuration loaded by future shells. Keep the checkout in a permanent location.
- The general dotfile installer accepts `--dry-run`, **not `--force`**. Its copy/backup policy still applies on a normal run. The separate completion installer has a different, stricter ownership and backup contract.

For existing custom configuration, consider omitting the relevant steps:

```bash
bash setup.sh --skip=dotfiles
```

```powershell
.\setup.ps1 -Skip 'dotfiles,profile'
```

Other selected installers can still configure their own shell/PATH integration. These flags do not make the entire run read-only. See the [dotfile and completion reference](../config/dotfiles/README.md) for exact behavior.

## Versions and Individual Installers

[`.tool-versions`](../.tool-versions) is the pin registry; setup reads it directly without requiring asdf or mise. The Node step targets the `nodejs` pin. If that Node version is already present, it may skip bootstrapping NVM.

To change a version deliberately, update its pin and rerun the relevant selection. Package-manager constraints can cause visible drift; see [version-pin enforcement](../CONTRIBUTING.md#tool-version-pin-enforcement). Do not replace pinned examples with an undocumented latest-version install.

Tools remain individually invocable, but their dependencies are your responsibility. Prefer the ordered top-level selection unless diagnosing a specific installer. Adding a supported tool is covered in [Architecture](../ARCHITECTURE.md#how-to-add-a-new-tool-linuxmacos).

## After Setup

Open a fresh terminal, then check the tools you selected:

```sh
node --version
npm --version
gh --version
```

Compare versioned tools with the pin registry rather than installing an unrelated latest LTS as a post-setup step. If PATH has not refreshed, use a new terminal and inspect the installer's diagnostic before rerunning it.

The `auth` step reuses an authenticated GitHub CLI or offers interactive `gh auth login`. It skips prompting in noninteractive environments. If authentication was skipped and you need it, run `gh auth login` deliberately.

Aliases and functions are loaded by shell/profile startup. A fresh terminal is important after removing definitions: sourcing a newer file does not necessarily erase an old alias already held in the current shell. User-maintained definitions outside managed configuration are not silently removed.

## Uninstalling or Moving the Checkout

Installed tool packages are not removed by this repository's general uninstallers. Review the platform script and available backups before using [Unix uninstall](../scripts/linux/uninstall.sh) or [Windows uninstall](../scripts/windows/uninstall.ps1); do not treat them as a complete rollback of later personal edits.

If you enabled native completion, [remove that opt-in separately](../config/dotfiles/README.md#disable-remove-or-recover) before the general uninstall or moving/deleting the checkout. Review other symlinks too. Never blindly restore an old backup over newer configuration.
