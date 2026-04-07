# examples/

This directory contains reference dotfiles and configuration templates that
reflect the owner's personal setup. They serve as the source of truth for
what gets installed by the setup scripts.

---

## Files

| File | Description |
|------|-------------|
| `.bashrc-example` | Bash/Zsh aliases, tmux helper functions, and the `start_up` hook. Used as the source for `config/dotfiles/.aliases`. |
| `.vimrc-example` | Full Vim configuration. Installed to `config/dotfiles/.vimrc` and symlinked to `~/.vimrc` by `config/dotfiles/install.sh`. |
| `Microsoft.PowerShell_profile-example.ps1` | PowerShell aliases and Linux-compatible functions. Written to `$PROFILE` by `scripts/windows/setup.ps1`. |

---

## How to use

These files are **reference examples** — they are not sourced directly.
The setup scripts read from them and install their contents automatically:

- **Linux/macOS:** run `bash setup.sh` (or `bash config/dotfiles/install.sh` for dotfiles only)
- **Windows:** run `scripts\windows\setup.ps1`

To customise the owner's shortcuts, edit the relevant file here and re-run
the appropriate setup script.
