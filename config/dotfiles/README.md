# Dotfile Templates

These templates give every Dev Container and Codespace a sensible, consistent environment right out of the box -- no manual config required on day one.

---

## Files

| File | Destination | Method | Notes |
|------|-------------|--------|-------|
| `.gitconfig.template` | `$HOME/.gitconfig` | Copy | Editable per-machine |
| `.editorconfig` | `$HOME/.editorconfig` | Symlink | Shared, not machine-specific |
| `.npmrc.template` | `$HOME/.npmrc` | Copy | Editable per-machine |
| `.vimrc` | `$HOME/.vimrc` | Symlink | Vim configuration |
| `install.sh` | -- | Script | Idempotent installer |
| `install-completion.sh` | -- | Script | Separate, explicit completion-only opt-in |
| `completion.sh` | `$HOME/.dev-setup-completion.sh` | Symlink | Interactive Bash/Zsh native completion bindings |

---

## Quick Start

```bash
# From the repo root:
bash config/dotfiles/install.sh

# Preview what would happen without changing anything:
bash config/dotfiles/install.sh --dry-run
```

---

## Opt-in Tab completion cycling (Bash / Zsh)

**This is not enabled by `setup.sh` or `install.sh`.** Both existing and fresh
installations use the same separate command, without reinstalling other dotfiles:

```bash
# From the repository root, after your normal shell/framework setup:
bash config/dotfiles/install-completion.sh --dry-run
bash config/dotfiles/install-completion.sh
# Open a fresh interactive shell afterward.
```

| Shell | Tab | Shift+Tab |
|-------|-----|-----------|
| Bash with native `menu-complete-backward` | Next match | Previous match |
| **macOS system Bash 3.2 / older Readline** | **Next match** | **Existing binding unchanged; no backward cycling added** |
| Zsh | Next match | Previous match |

The helper detects native Readline widget availability, not a Bash version
number. It deliberately does **not** add a macro fallback or reserve extra keys.
Opting in explicitly overrides existing Tab and (where supported) Shift+Tab
bindings in Bash's `emacs-standard` / `vi-insert` and Zsh's `emacs` / `viins`
keymaps. Editing mode, vi command mode, and unrelated bindings are preserved.
Custom keymaps outside these maps remain user-managed. The helper does nothing
in noninteractive shells. It is not a PowerShell feature.

### Ordering, terminals, and providers

- The installer appends a **separate** `dev-setup completion v1` hook at the end
  of each rc. Keep the entire hook, including its preceding separator newline,
  intact. Existing general DevSetup managed blocks are never edited.
- Put framework initialization, `compinit`, completion providers, and general
  key bindings **before** this hook. Later user configuration wins; frameworks
  loaded later may override it. If moving the hook, move its separator too.
- Zsh's native completion works without `compinit`. If your framework already
  initialized completion, these widget names reuse its providers/styles. This
  helper never runs `compinit` (which would also bind unrelated keys), installs
  a framework, or bypasses `compinit`'s security audit. Follow your framework's
  normal initialization/security instructions for richer completion.
- Commands, files, and directories work natively. Git branches, tool flags,
  package names, etc. depend on separately configured completion providers
  (such as `bash-completion` or Zsh's completion system). Their filtering and
  ordering still apply. This is not fuzzy search or an autosuggestion plugin.
- Shift+Tab must reach the shell as **ESC `[Z`**. Some terminals, IDEs, and
  multiplexers intercept it or send another sequence; configure them yourself.
  Tab/Ctrl-I are the same terminal key. Existing Readline variables and Zsh
  completion styles may affect listing, ordering, or wraparound behavior.
- Bash login shells, especially macOS Terminal, may not read `.bashrc` unless
  your existing login profile sources it. This command **never edits
  `.bash_profile`**; choose that startup arrangement yourself.

### `ZDOTDIR` and ownership safety

The command targets **both** `$HOME/.bashrc` and `${ZDOTDIR:-$HOME}/.zshrc`;
Zsh need not be installed at opt-in time. If you use `ZDOTDIR`, export its
**effective absolute path** when installing, previewing, or uninstalling:

```bash
ZDOTDIR="$HOME/.config/zsh" bash config/dotfiles/install-completion.sh
```

The directory must already exist. The command never executes `.zshenv` to
infer configuration. If `$HOME/.zshenv` exists, an explicit `ZDOTDIR` is required
(use `ZDOTDIR="$HOME"` if it does not relocate rc files). Ensure it matches the
value used by your shell; changing `ZDOTDIR` later requires removing the old
hook using the old value first. Empty/relative/missing `ZDOTDIR` is rejected.

Trailing/repeated slashes and `.` or `..` components are supported for real
directories. **Every component of the absolute `ZDOTDIR` path is checked for
symlinks**, including ancestors: `link/`, `link/.`, `link/child`, and
`link/../other` are all rejected if `link` is a symlink. The supplied path is
not resolved or rewritten to silently choose a target. Use a symlink-free
absolute path (for example, `/private/tmp/...` rather than `/tmp/...` on macOS
when `/tmp` is a symlink). This is preflight validation, not a filesystem-race
or sandbox guarantee.

Both rc files and the helper destination are validated before any mutation.
Symlinked rc files, symlinks in `ZDOTDIR` paths, conflicting helper links,
user-owned files at the helper destination, and malformed/modified/duplicate
hooks are rejected rather than overwritten. Binary/NUL rc content and paths
containing newlines are unsupported. Spaces and shell metacharacters in paths
are supported. If validation fails, review the indicated configuration manually;
do not delete user configuration just to make the check pass.

Existing rc files are backed up to unique
`<rc>.dev-setup-completion.bak.XXXXXX` files before edits. Backups retain file
permissions and are not automatically pruned or used to overwrite later edits.
Bytes outside the owned hook are retained. When the hook is at EOF, removal
restores the original bytes exactly, including a missing final newline. When
text follows the hook, removal retains one separator newline if otherwise a
nonempty, unterminated preceding line would join that following text. No extra
separator is retained if the preceding text is empty, already ends in a newline,
or the following text starts with a newline. This keeps later assignments
separate without restoring a whole backup or changing any user-added bytes.
Re-running the command does not duplicate hooks or create new backups.
`--dry-run` performs validation but creates no files, directories, links, or backups.

The helper link points into **this checkout**. Keep it in place; updating
`completion.sh` updates already opted-in shells on their next startup, without
rewriting hooks. To move/remove a checkout, uninstall this feature using the
original checkout first. A link into a different checkout is a conflict, not an
implicit migration.

### Disable, remove, or recover

For a temporary disable, export this **before the hook** (or in the parent
process environment), then open a **fresh** shell:

```bash
export DEV_SETUP_COMPLETION=0
```

This leaves that fresh shell's prior bindings intact. Setting it after the
helper already ran does not undo current-shell bindings. Unset it to re-enable
in future shells. Do not place the switch inside the owned hook.

To remove only this feature, without reinstalling or restoring other dotfiles:

```bash
bash config/dotfiles/install-completion.sh --uninstall --dry-run
bash config/dotfiles/install-completion.sh --uninstall
```

Removal validates both targets, backs up changed rc files, removes only the
owned hook (with the separator rule above) and expected helper link, and preserves
later user additions. Newly created rc files are left empty rather than deleted.
Repeated removal is safe.
Open a fresh shell to get normal bindings back. Remove this feature separately
**before** the general DevSetup uninstaller or deleting the checkout; the general
uninstaller does not manage this opt-in hook.

Avoid concurrent edits/installers. Replacements are prepared and backups made
before activating hooks, with a snapshot recheck, but this is **not a multi-file
transaction or a filesystem lock**. On an I/O failure, inspect the diagnostic,
current hooks, helper link, and named backups; fix the underlying problem and
rerun. Never blindly restore a backup over newer user additions.

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
remain in `$HOME/.gitconfig` -- just edit the file manually.

**Included defaults (and why):**

| Setting | Value | Reason |
|---------|-------|--------|
| `core.autocrlf` | `input` | Normalise line endings to LF on commit; safe cross-platform |
| `core.editor` | `vim` | Sensible default; override with `git config --global core.editor <editor>` |
| `pull.rebase` | `false` | Merge on pull is a safe, explicit default |
| `init.defaultBranch` | `main` | Modern default; avoids `master` |
| `push.autoSetupRemote` | `true` | Skip manual `-u origin <branch>` on first push (Git >= 2.37) |
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

**Shell Aliases:**

| Alias | Expands to |
|-------|-----------|
| `gosquad` | `copilot --agent squad --yolo` |

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
| `[Makefile]` | **tab** | -- | `make` requires real tabs |
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
| `set nocompatible` | -- | Disable vi compatibility mode |
| `set number` | -- | Show line numbers |
| `set cursorline/column` | -- | Highlight cursor position |
| `set shiftwidth=4` | 4 | 4-space indentation |
| `set tabstop=4` | 4 | Tab = 4 spaces |
| `set expandtab` | -- | Expand tabs to spaces |
| `set nowrap` | -- | Disable line wrapping |
| `set incsearch` | -- | Incremental search |
| `set ignorecase` / `smartcase` | -- | Smart case-insensitive search |
| `set hlsearch` | -- | Highlight search matches |
| `set wildmenu` | -- | Better command-line completion |

---

## How Idempotency Works

`install.sh` is safe to run multiple times:

- **Symlinks:** If `$HOME/.editorconfig` already points to the correct target,
  the script prints `-> Already installed: .editorconfig` and skips it.
  If the symlink points somewhere else, it is replaced.

- **Copied files:** If `$HOME/.gitconfig` already exists and matches the
  template exactly, the script skips it. If the file exists but differs
  (e.g. you've edited it), the existing file is backed up to
  `$HOME/.gitconfig.bak` before the template is copied.

- **Backups:** A `.bak` file is only created once per run -- subsequent runs
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
