# Dev Container & GitHub Codespaces

This directory configures the development environment for opening this repo in a [VS Code Dev Container](https://code.visualstudio.com/docs/devcontainers/containers) or [GitHub Codespaces](https://github.com/features/codespaces).

---

## What Is a Dev Container?

A Dev Container is a fully configured, reproducible development environment defined in code. When you open this repo in VS Code with the Dev Containers extension (or in GitHub Codespaces), the container spins up automatically with all tools, extensions, and shell configuration pre-installed — no manual setup required.

---

## How to Open

### VS Code (Remote - Containers)

1. Install the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
2. Clone this repo
3. Open the repo folder in VS Code
4. When prompted, click **"Reopen in Container"** — or run the command palette command: `Dev Containers: Reopen in Container`

VS Code will build the container and run `postCreateCommand` automatically.

### GitHub Codespaces

1. Navigate to the repo on GitHub
2. Click the green **Code** button → **Codespaces** tab → **Create codespace on develop**
3. The Codespace will start, build the container, and run `postCreateCommand` automatically

---

## What `postCreateCommand` Does

After the container is created, the following runs automatically:

```bash
bash setup.sh
```

`setup.sh` is the repo's Unix entry point. It detects the OS (Linux, macOS, or WSL) and routes to the appropriate setup script. Inside a Dev Container or Codespace the environment is Linux (Ubuntu), so it will run `scripts/linux/setup.sh`, which:

- Installs **zsh** and sets it as the default shell
- Installs **uv** (Python package manager)
- Installs **nvm** and the latest LTS Node.js
- Installs **gh** (GitHub CLI)
- Installs **GitHub Copilot CLI** extension for gh
- Sets up **dotfiles** and shell configuration
- Applies **shortcuts** and aliases

The script is idempotent — safe to run multiple times without side effects.

---

## Devcontainer Features

The following [devcontainer features](https://containers.dev/features) are pre-installed before `postCreateCommand` runs:

| Feature | Why |
|---|---|
| `ghcr.io/devcontainers/features/git:1` | Ensures a recent version of git is available |
| `ghcr.io/devcontainers/features/github-cli:1` | Ensures `gh` is available early so the Copilot CLI can be installed during postCreate |

---

## Pre-installed VS Code Extensions

| Extension | Purpose |
|---|---|
| `GitHub.copilot` | AI-powered code completions |
| `GitHub.copilot-chat` | Copilot Chat panel for in-editor AI chat |
| `timonwong.shellcheck` | Shell script linting (ShellCheck) |
| `foxundermoon.shell-format` | Shell script formatting |
| `mads-hartmann.bash-ide-vscode` | Bash language server (hover docs, go-to-definition) |
| `ms-vscode.powershell` | PowerShell language support (for `setup.ps1`) |
| `editorconfig.editorconfig` | Respects `.editorconfig` for consistent formatting |
| `eamodio.gitlens` | Enhanced Git history, blame, and authorship |
| `GitHub.vscode-pull-request-github` | Create and review PRs from within VS Code |
| `GitHub.vscode-github-actions` | View and manage GitHub Actions workflows |

---

## VS Code Settings (Container-scoped)

These settings apply automatically inside the container:

| Setting | Value | Why |
|---|---|---|
| `terminal.integrated.defaultProfile.linux` | `zsh` | Uses zsh (installed by setup.sh) as the default terminal |
| `editor.formatOnSave` | `true` | Auto-format on save using installed formatters |
| `editor.rulers` | `[100]` | Visual line-length guide at 100 characters |
| `files.eol` | `\n` | Enforce Unix line endings |
| `shellcheck.enable` | `true` | Enable ShellCheck linting |
| `shellcheck.run` | `onType` | Lint shell scripts as you type |

---

## Customizing the Container

To customize for your own use without affecting the team config:

- **VS Code user settings:** Use your VS Code profile / user settings (these layer on top of the container settings)
- **Dotfiles:** GitHub Codespaces supports [personal dotfiles repos](https://docs.github.com/en/codespaces/setting-your-user-preferences/personalizing-github-codespaces-for-your-account#dotfiles) — link yours in your Codespaces settings
- **Additional tools:** Add steps to `scripts/linux/setup.sh` or create a personal `~/.local/bin` script that runs after setup

---

## Base Image

```
mcr.microsoft.com/devcontainers/base:ubuntu
```

Microsoft's official Ubuntu-based devcontainer base image. Includes common developer tools (curl, wget, git, etc.) and the devcontainer toolchain. See the [image definition](https://github.com/devcontainers/images/tree/main/src/base-ubuntu) for full details.

---

## Required Codespace Secrets

Set these in GitHub → Settings → Codespaces → Secrets:

| Secret | Description | Default |
|--------|-------------|---------|
| `GIT_AUTHOR_NAME` | Your full name for git commits | `Earl Tankard, Jr., Ph.D.` |
| `GIT_AUTHOR_EMAIL` | Your email for git commits | `45021016+primetimetank21@users.noreply.github.com` |

These are applied automatically on `postCreateCommand` when the devcontainer starts.
