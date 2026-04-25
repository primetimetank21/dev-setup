# dev-setup

> One-command developer environment setup for Linux, macOS, WSL, Windows, and GitHub Codespaces.

## What This Installs

| Tool | Purpose |
|------|---------|
| `zsh` | Shell — installed and set as default on Linux/macOS |
| `uv` | Python package and environment manager (fast pip replacement) |
| `nvm` + Node.js LTS | Node Version Manager + latest Node LTS |
| `gh` | GitHub CLI |
| GitHub Copilot CLI | AI pair programmer in your terminal (`gh copilot`) |
| `vim` | Modal text editor — installed on all platforms |
| `tmux` | Terminal multiplexer (Linux/macOS) |
| `psmux` | Terminal multiplexer (Windows) |
| `squad-cli` | AI agent orchestration tool (installed via npm) |
| Shell aliases | Shortcuts for common git and dev commands |

## Supported Platforms

| Platform | Status | Entry point |
|----------|:------:|-------------|
| Linux (native) | ✅ | `bash setup.sh` |
| macOS | ✅ | `bash setup.sh` |
| WSL (Windows Subsystem for Linux) | ✅ | `bash setup.sh` |
| Windows (native PowerShell) | ✅ | `powershell -ExecutionPolicy Bypass -File setup.ps1` |
| Dev Container / GitHub Codespace | ✅ | Automatic (runs on container creation) |

## Quick Start

### Linux / macOS / WSL

```bash
git clone https://github.com/primetimetank21/dev-setup.git
cd dev-setup
bash setup.sh
```

> **GitHub Authentication:** During setup, `auth.sh` checks whether you are already authenticated with the GitHub CLI. If not, it launches `gh auth login` interactively so you can complete authentication. In non-interactive environments (CI, GitHub Codespaces, piped stdin), the prompt is skipped automatically and a warning is printed — run `gh auth login` manually after setup completes if you need to authenticate.

### Windows (PowerShell)

```powershell
git clone https://github.com/primetimetank21/dev-setup.git
cd dev-setup
powershell -ExecutionPolicy Bypass -File setup.ps1
```

### Dev Container / GitHub Codespace

No action needed. Setup runs automatically on container creation via the `postCreateCommand` hook.

## Post-Setup Steps

After running setup, complete these steps to activate your tools:

### Linux / macOS / WSL

1. **Activate Node.js:**
   ```bash
   nvm install --lts
   nvm use --lts
   ```

2. **Dotfiles:** Your shell config (`.zshrc`/`.bashrc`) and aliases are automatically installed during setup. Restart your terminal or run `source ~/.zshrc` (or `source ~/.bashrc` for bash) to load them.

### Windows

1. **Activate Node.js:** Open a new terminal and run:
   ```powershell
   nvm install lts
   nvm use lts
   ```

2. **Aliases:** PowerShell aliases are automatically added to your profile. Restart your terminal to load them.

## Repo Structure

```
dev-setup/
├── setup.sh                  — Entry point for Linux / macOS / WSL
├── setup.ps1                 — Entry point for Windows (PowerShell)
├── scripts/
│   ├── linux/
│   │   ├── setup.sh          — Core Linux/macOS installer (orchestrates tool scripts)
│   │   └── tools/            — Individual tool install scripts
│   │       ├── zsh.sh
│   │       ├── uv.sh
│   │       ├── nvm.sh
│   │       ├── gh.sh
│   │       └── copilot-cli.sh
│   └── windows/
│       └── setup.ps1         — Core Windows installer (PowerShell)
├── config/
│   └── dotfiles/             — Dotfile templates (.gitconfig, .editorconfig, .npmrc)
├── examples/                 — Reference dotfiles and config templates
├── .github/
│   └── workflows/            — CI validation workflows (GitHub Actions)
└── ARCHITECTURE.md           — Technical architecture and team ownership map
```

Root entry points (`setup.sh`, `setup.ps1`) are thin routers — they detect the OS and delegate to the appropriate script under `scripts/`. They install nothing themselves.

## Shell Aliases

After running setup, you get shortcuts for common git, dev, and utility commands. All aliases work on both Linux/macOS and Windows.

### Alias Groups

**Git shortcuts:** `ga`, `gaa`, `gc`, `gcm`, `gcb`, `gco`, `gd`, `gds`, `gf`, `gfp`, `ggs`, `ggsls`, `ggsp`, `gl`, `glog`, `gp`, `gpf`, `gpl`, `grb`, `grbi`, `grs`, `grss`, `gs`

**GitHub CLI:** `ghpr`, `ghprl`, `ghprv`, `ghis`, `ghiv`

**Dev tools:** `uvr`, `uvs`, `ni`, `nr`, `nrd`, `nrt`, `py`, `c`

**Utility:** `myip`, `pb`, `h`, `ep`

**tmux/psmux:** `ta` (attach), `tt` (new session), `tls` (list sessions), `tks` (kill server)

**Navigation** (Linux/macOS only): `..`, `...`, `....`, `~`, `-`

**ls shortcuts** (Linux/macOS only): `ll`, `la`, `l`, `lh`

Full definitions:
- **Linux/macOS:** `config/dotfiles/.aliases`
- **Windows:** `scripts/windows/setup.ps1` (the `Write-PowerShellProfile` function)

## Shell Functions

Three helper functions are available after setup:

### Linux / macOS / WSL

**`create_tmux`** — Create or attach to the `tank_dev` tmux session. If the session exists, attaches to it. If not, creates it first.

```bash
create_tmux
```

**`start_up`** — Shortcut that calls `create_tmux`. Use this in your shell startup for auto-attach.

```bash
start_up
```

### Windows

**`New-PsmuxSession`** — Create or attach to the `tank_dev` psmux session (Windows equivalent of `create_tmux`).

```powershell
New-PsmuxSession
```

## Git Hooks (Auto-configured)

Both `setup.sh` and `setup.ps1` automatically configure git to use this repo's hooks directory:

```bash
git config core.hooksPath hooks
```

No manual copying needed. After running setup, three hooks are active:

### `pre-commit`

Runs shellcheck on staged `.sh` files. Blocks commit if shellcheck fails. Silently skips if shellcheck not installed.

### `commit-msg`

Enforces **Conventional Commits** format:

```
type(scope): description
```

Valid types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `ci`, `build`, `perf`, `revert`. Hard reject on non-conforming messages.

### `pre-push`

1. **Blocks** direct pushes to `main` (hard stop).
2. **Runs shellcheck** on changed `.sh` files — advisory, never blocks (Linux/macOS).
3. **Runs PSScriptAnalyzer** on changed `.ps1` files — advisory, never blocks (requires `pwsh` + PSScriptAnalyzer module; silently skipped if absent).

Use `--no-verify` to bypass hooks in emergencies.

---

## Customization

**Dotfiles:** Edit or add templates in `config/dotfiles/`. Each file is copied into your home directory on first run. Existing files are not overwritten unless you pass `--force`.

**Adding a tool:** Drop a new script in `scripts/linux/tools/` (or `scripts/windows/`) following the naming pattern of existing tools, then call it from `scripts/linux/setup.sh` (or the Windows equivalent). Scripts must be idempotent — check whether the tool is already installed before doing anything.

## Contributing

This repo is maintained by the **dev-setup squad** — a set of specialized AI agents, each owning a slice of the codebase. See [ARCHITECTURE.md](./ARCHITECTURE.md) for the full technical overview, team ownership map, and guide on how to add a new tool.

---

For deeper technical detail — OS detection logic, script conventions, decision records — see [ARCHITECTURE.md](./ARCHITECTURE.md).
