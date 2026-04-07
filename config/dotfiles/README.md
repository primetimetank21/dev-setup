# Dotfile Templates

Managed by **Pluto** (Config Engineer). These templates give every Dev Container
and Codespace a sensible, consistent environment right out of the box — no
manual config required on day one.

---

## Files

| File | Destination | Method | Notes |
|------|-------------|--------|-------|
| `.gitconfig.template` | `$HOME/.gitconfig` | Copy | Editable per-machine |
| `.editorconfig` | `$HOME/.editorconfig` | Symlink | Shared, not machine-specific |
| `.npmrc.template` | `$HOME/.npmrc` | Copy | Editable per-machine |
| `.vimrc` | `$HOME/.vimrc` | Symlink | Vim configuration |
| `install.sh` | — | Script | Idempotent installer |

---

## Quick Start

```bash
# From the repo root:
bash config/dotfiles/install.sh

# Preview what would happen without changing anything:
bash config/dotfiles/install.sh --dry-run
```

---

## Customisation

### `.gitconfig`

After running `install.sh`, a copy lives at `$HOME/.gitconfig`.  
Edit it directly for machine-specific values.

**Env-var substitution at install time:**

Set these before running `install.sh` and the script will fill them in
automatically:

| Env var | Replaces | Example |
|---------|----------|---------|
| `GIT_AUTHOR_NAME` | `YOUR_NAME` | `Earl Tankard` |
| `GIT_AUTHOR_EMAIL` | `YOUR_EMAIL` | `earl@example.com` |
| `GIT_AUTHOR_SIGNING_KEY` | `YOUR_SIGNING_KEY` | `ABC123DEF456` |

```bash
export GIT_AUTHOR_NAME="Your Name"
export GIT_AUTHOR_EMAIL="you@example.com"
bash config/dotfiles/install.sh
```

If the env vars are not set, the placeholders (`YOUR_NAME`, `YOUR_EMAIL`)
remain in `$HOME/.gitconfig` — just edit the file manually.

**Included defaults (and why):**

| Setting | Value | Reason |
|---------|-------|--------|
| `core.autocrlf` | `input` | Normalise line endings to LF on commit; safe cross-platform |
| `core.editor` | `${EDITOR:-vim}` | Honour user preference; fall back to vim |
| `pull.rebase` | `false` | Merge on pull is a safe, explicit default |
| `init.defaultBranch` | `main` | Modern default; avoids `master` |
| `push.autoSetupRemote` | `true` | Skip manual `-u origin <branch>` on first push (Git ≥ 2.37) |
| `merge.ff` | `false` | Always create a merge commit for clear history |
| `fetch.prune` | `true` | Keep local refs clean when remote branches are deleted |
| `diff.algorithm` | `histogram` | Better diff quality for code and prose |

**Aliases:**

| Alias | Expands to |
|-------|-----------|
| `git co` | `git checkout` |
| `git br` | `git branch` |
| `git st` | `git status -sb` |
| `git lg` | Pretty one-line graph log |
| `git undo` | `git reset --soft HEAD~1` |
| `git unstage` | `git restore --staged` |

---

### `.editorconfig`

This file is **symlinked** to `$HOME/.editorconfig`, so updates to the repo
template propagate automatically (unlike the copied dotfiles).

Most editors pick up `$HOME/.editorconfig` as a global fallback when no
project-level `.editorconfig` is found. The file is also checked into the
repo root, so it applies to this project directly.

**Key rules:**

| Pattern | indent_style | indent_size | Notes |
|---------|-------------|-------------|-------|
| `[*]` | space | 2 | Baseline for everything |
| `[*.md]` | space | 2 | `trim_trailing_whitespace = false` (Markdown hard breaks) |
| `[Makefile]` | **tab** | — | `make` requires real tabs |
| `[*.sh]` | space | 2 | Explicit (matches baseline) |
| `[*.ps1]` | space | **4** | Microsoft PowerShell convention |
| `[*.py]` | space | **4** | PEP 8 |

---

### `.npmrc`

After running `install.sh`, a copy lives at `$HOME/.npmrc`.  
Edit it directly for machine-specific settings.

**Included defaults (and why):**

| Setting | Value | Reason |
|---------|-------|--------|
| `save-exact` | `true` | Pin exact versions; prevents silent upgrades across machines |
| `fund` | `false` | Suppress funding nags on install |
| `audit` | `false` | Run `npm audit` deliberately rather than on every install |
| `loglevel` | `warn` | Keep install output readable |

**Optional: registry auth**

Uncomment and set env vars in your shell profile (e.g. `~/.zshrc.local`):

```bash
# Public npm registry (personal token)
export NPM_TOKEN="npm_..."

# GitHub Packages (private org packages)
export GITHUB_TOKEN="ghp_..."
```

Then uncomment the relevant lines in `$HOME/.npmrc`.  
**Never hardcode tokens in any file.**

---

### `.vimrc`

After running `install.sh`, a symlink is created at `$HOME/.vimrc` pointing to
`config/dotfiles/.vimrc`.

Edit `config/dotfiles/.vimrc` in the repo and the changes apply immediately
(no re-run needed thanks to the symlink).

**Included settings:**

| Setting | Value | Reason |
|---------|-------|--------|
| `set nocompatible` | — | Disable vi compatibility mode |
| `set number` | — | Show line numbers |
| `set cursorline/column` | — | Highlight cursor position |
| `set shiftwidth=4` | 4 | 4-space indentation |
| `set tabstop=4` | 4 | Tab = 4 spaces |
| `set expandtab` | — | Expand tabs to spaces |
| `set nowrap` | — | Disable line wrapping |
| `set incsearch` | — | Incremental search |
| `set ignorecase` / `smartcase` | — | Smart case-insensitive search |
| `set hlsearch` | — | Highlight search matches |
| `set wildmenu` | — | Better command-line completion |

---

## How Idempotency Works

`install.sh` is safe to run multiple times:

- **Symlinks:** If `$HOME/.editorconfig` already points to the correct target,
  the script prints `→ Already installed: .editorconfig` and skips it.
  If the symlink points somewhere else, it is replaced.

- **Copied files:** If `$HOME/.gitconfig` already exists and matches the
  template exactly, the script skips it. If the file exists but differs
  (e.g. you've edited it), the existing file is backed up to
  `$HOME/.gitconfig.bak` before the template is copied.

- **Backups:** A `.bak` file is only created once per run — subsequent runs
  see the template file in place and skip.

---

## Dry Run

Pass `--dry-run` to preview all actions without making any changes:

```bash
bash config/dotfiles/install.sh --dry-run
```

---

## Adding New Dotfiles

1. Add the template file to `config/dotfiles/` (use `.template` suffix for
   files that users typically customise per-machine).
2. Add an `install_copy` or `install_symlink` call in `install.sh`.
3. Document it in this README.
