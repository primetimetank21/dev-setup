#!/usr/bin/env bash
# Completion-only opt-in. Does not run install.sh or source any user startup file.
# Bash 3.2 compatible; only standard Linux/macOS utilities are required.
set -euo pipefail
export LC_ALL=C

usage() {
    cat <<'HELP'
Usage: bash config/dotfiles/install-completion.sh [--dry-run] [--uninstall]

Opt in BOTH ~/.bashrc and ${ZDOTDIR:-$HOME}/.zshrc, or remove only this feature.
Ordinary DevSetup installation does not enable completion cycling.
Tab cycles forward. Shift+Tab cycles backward in Zsh and in Bash with native
menu-complete-backward; macOS Bash 3.2 leaves existing Shift+Tab UNCHANGED.
Export DEV_SETUP_COMPLETION=0 before the hook to disable in a fresh shell.
Export ZDOTDIR explicitly if ~/.zshenv exists; no startup files are executed to
infer its value. Symlinked rc files and conflicting helper links are rejected.
Existing rc files are backed up before edits. Keep the repository in place.
See config/dotfiles/README.md for ordering, recovery, and compatibility limits.
HELP
}
die() { printf 'completion: %s\n' "$*" >&2; exit 1; }
DRY_RUN=false
UNINSTALL=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --uninstall) UNINSTALL=true ;;
        --help|-h) usage; exit 0 ;;
        *) die "unknown argument: $arg (see --help)" ;;
    esac
done

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
SOURCE="$DOTFILES_DIR/completion.sh"
[[ -f "$SOURCE" && ! -L "$SOURCE" ]] || die "missing regular helper: $SOURCE"
[[ "${HOME:-}" == /* && -d "$HOME" && -w "$HOME" && -x "$HOME" ]] || die 'HOME must be an existing writable, searchable absolute directory'
if [[ -z "${ZDOTDIR+x}" && ( -e "$HOME/.zshenv" || -L "$HOME/.zshenv" ) ]]; then
    die 'export the effective ZDOTDIR (use HOME if unchanged); ~/.zshenv exists and will not be executed'
fi
ZSH_DIR=${ZDOTDIR-$HOME}
[[ "$ZSH_DIR" == /* && -d "$ZSH_DIR" && -w "$ZSH_DIR" && -x "$ZSH_DIR" ]] ||
    die 'ZDOTDIR must be an existing writable, searchable absolute directory'
# Check every component before a trailing slash, dot or later .. can hide a
# symlink from -L. Empty slash-separated components are harmless; do not resolve
# the path or collapse .. before checking preceding components. Keep ZSH_DIR
# unchanged for file operations. This preflight does not prevent filesystem races.
directory_remaining=${ZSH_DIR#/}
directory_prefix=''
while [[ -n "$directory_remaining" ]]; do
    component=${directory_remaining%%/*}
    if [[ "$directory_remaining" == */* ]]; then directory_remaining=${directory_remaining#*/};
    else directory_remaining=''; fi
    [[ -n "$component" ]] || continue
    directory_prefix="$directory_prefix/$component"
    [[ ! -L "$directory_prefix" ]] || die "symlink in ZDOTDIR path: $directory_prefix"
done
# Newlines in paths are deliberately unsupported; spaces, quotes and shell
# metacharacters are safe because the hook uses HOME, not interpolated code.
case "$HOME$ZSH_DIR$DOTFILES_DIR" in *$'\n'*) die 'newline in configuration path is unsupported' ;; esac
LINK="$HOME/.dev-setup-completion.sh"
if [[ -L "$LINK" ]]; then
    [[ "$(readlink "$LINK")" == "$SOURCE" ]] || die "conflicting helper symlink: $LINK"
elif [[ -e "$LINK" ]]; then
    die "helper path is user-managed, not the expected symlink: $LINK"
fi

# The leading separator newline belongs to this block. At EOF, removal restores
# an original missing final newline; between user text, retain it if needed to
# keep lines separate. Hook text stays stable across helper upgrades.
# shellcheck disable=SC2016
BLOCK=$'\n''# >>> dev-setup completion v1 (do not edit) >>>
[ ! -r "$HOME/.dev-setup-completion.sh" ] || . "$HOME/.dev-setup-completion.sh"
# <<< dev-setup completion v1 <<<'$'\n'
FILES=("$HOME/.bashrc" "$ZSH_DIR/.zshrc")
BEFORE=()
AFTER=()
CHANGED=(false false)
EXISTED=(false false)
TEMPS=('' '')

# Validate EVERY target before creating links, backups, files or directories.
for i in 0 1; do
    file=${FILES[$i]}
    [[ ! -L "$file" ]] || die "symlinked rc is ambiguous: $file"
    text=''
    if [[ -e "$file" ]]; then
        [[ -f "$file" && -r "$file" && -w "$file" ]] || die "rc must be a readable writable regular file: $file"
        EXISTED[i]=true
        # The sentinel retains all trailing newlines. Reject NUL/binary content
        # that Bash cannot represent rather than silently dropping bytes.
        text=$(cat "$file"; printf '.')
        text=${text%.}
        cmp -s "$file" <(printf '%s' "$text") || die "rc is not representable as shell text: $file"
    fi
    BEFORE[i]=$text
    remainder=${text/"$BLOCK"/}
    if [[ "$remainder" == *'dev-setup completion'* || "$remainder" == *'.dev-setup-completion.sh'* ]]; then
        die "malformed, duplicate or modified completion hook: $file (review manually)"
    fi
    if [[ "$UNINSTALL" == true ]]; then
        if [[ "$remainder" != "$text" ]]; then
            prefix=${text%%"$BLOCK"*}
            suffix=${text#*"$BLOCK"}
            # Do not fuse an unterminated original line with a later addition.
            if [[ -n "$prefix" && "$prefix" != *$'\n' && -n "$suffix" && "$suffix" != $'\n'* ]]; then
                remainder="$prefix"$'\n'"$suffix"
            fi
        fi
        AFTER[i]=$remainder
    elif [[ "$remainder" == "$text" ]]; then
        AFTER[i]="$text$BLOCK"
    else
        AFTER[i]=$text
    fi
    if [[ "${AFTER[$i]}" != "$text" ]]; then CHANGED[i]=true; fi
done

printf 'Completion: Tab forward; Shift+Tab backward only with a native backward widget.\n'
printf 'macOS Bash 3.2: forward only; existing Shift+Tab is preserved. Zsh: both directions.\n'
for i in 0 1; do
    if [[ "${CHANGED[$i]}" == true ]]; then
        printf '%s: %s\n' "${FILES[$i]}" 'would back up (if present) and update completion hook'
    else
        printf '%s: unchanged\n' "${FILES[$i]}"
    fi
done
if [[ "$DRY_RUN" == true ]]; then
    printf '[dry-run] No changes. Helper link would be reconciled for this operation: %s\n' "$LINK"
    exit 0
fi

cleanup() {
    for i in 0 1; do
        if [[ -n "${TEMPS[$i]}" ]]; then rm -f -- "${TEMPS[$i]}"; fi
    done
}
trap cleanup EXIT
# Prepare replacements and ALL backups before activating any hook. Unique
# backup names never overwrite or prune earlier recovery copies.
for i in 0 1; do
    [[ "${CHANGED[$i]}" == true ]] || continue
    file=${FILES[$i]}
    TEMPS[i]=$(mktemp "$file.dev-setup-completion.tmp.XXXXXX")
    if [[ "${EXISTED[$i]}" == true ]]; then
        cp -p "$file" "${TEMPS[$i]}"
        backup=$(mktemp "$file.dev-setup-completion.bak.XXXXXX")
        cp -p "$file" "$backup"
        printf 'Backup: %s\n' "$backup"
    fi
    printf '%s' "${AFTER[$i]}" > "${TEMPS[$i]}"
done
# Recheck snapshots before committing edits; never knowingly overwrite a file
# edited during preflight. This is not a multi-file transaction or a lock.
for i in 0 1; do
    file=${FILES[$i]}
    [[ ! -L "$file" ]] || die "rc became a symlink: $file"
    if [[ "${EXISTED[$i]}" == true ]]; then
        cmp -s "$file" <(printf '%s' "${BEFORE[$i]}") || die "rc changed during installation: $file"
    else
        [[ ! -e "$file" ]] || die "rc appeared during installation: $file"
    fi
done
if [[ "$UNINSTALL" == false && ! -L "$LINK" ]]; then
    ln -s "$SOURCE" "$LINK"
fi
for i in 0 1; do
    [[ "${CHANGED[$i]}" == true ]] || continue
    mv -f -- "${TEMPS[$i]}" "${FILES[$i]}"
    TEMPS[i]=''
done
if [[ "$UNINSTALL" == true && -L "$LINK" ]]; then
    [[ "$(readlink "$LINK")" == "$SOURCE" ]] || die 'helper link changed during uninstall; left in place'
    rm -- "$LINK"
fi
printf 'Done. Open a fresh shell; current-shell bindings are not changed or restored.\n'
