#!/usr/bin/env bash
# tests/test_aliases.sh -- Isolated alias loading and retirement regressions.
# No installed commands or personal rc files are used. The child PATH is empty;
# retained command aliases are exercised only against non-forwarding functions.
# Usage: bash tests/test_aliases.sh (TMPDIR may select the fixture parent).

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ALIASES_FILE="$REPO_ROOT/config/dotfiles/.aliases"
BASH_BIN="$BASH"
[[ "$BASH_BIN" == /* && -x "$BASH_BIN" ]] || { printf 'Absolute Bash executable required\n' >&2; exit 1; }
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dev-setup-aliases.XXXXXX")" || exit 1
PASS=0
FAIL=0

cleanup() {
    if [[ $FAIL -eq 0 ]]; then
        if rm -rf -- "$TEMP_ROOT" && [[ ! -e "$TEMP_ROOT" ]]; then
            printf 'Removed owned alias fixture: %s\n' "$TEMP_ROOT"
        else
            printf 'ERROR: alias fixture cleanup failed: %s\n' "$TEMP_ROOT" >&2
            exit 1
        fi
    else
        printf 'Retained failing alias fixture: %s\n' "$TEMP_ROOT" >&2
    fi
}
trap cleanup EXIT
mkdir -p "$TEMP_ROOT/home" "$TEMP_ROOT/bin" || exit 1
# Variables in fixture programs expand only in the isolated child.
# shellcheck disable=SC2016
printf '%s\n' 'printf "bash-rc\\n" >> "$RC_LOG"' > "$TEMP_ROOT/home/.bashrc"
# shellcheck disable=SC2016
printf '%s\n' 'printf "zsh-rc\\n" >> "$RC_LOG"' > "$TEMP_ROOT/home/.zshrc"

check() {
    local label="$1" codespaces="$2" body="$3"
    if (
        cd "$TEMP_ROOT" || exit 1
        # shellcheck disable=SC2016
        env -i HOME="$TEMP_ROOT/home" PATH="$TEMP_ROOT/bin" \
            CODESPACES="$codespaces" GITHUB_REPOSITORY='example/work-repo' \
            ZSH_VERSION='' RC_LOG="$TEMP_ROOT/rc.log" \
            "$BASH_BIN" --noprofile --norc -c '
                set -euo pipefail
                shopt -s expand_aliases
                source "$1"
                source "$1"
                eval "$2"
            ' aliases-test "$ALIASES_FILE" "$body"
    ); then
        printf 'PASS: %s\n' "$label"
        PASS=$((PASS + 1))
    else
        printf 'FAIL: %s\n' "$label" >&2
        FAIL=$((FAIL + 1))
    fi
}

# Only shell builtins are reachable while the entire production file is sourced.
# Removed installed binaries may still exist on the machine; this tests definitions,
# not machine cleanup. Shutdown functions are inspected, NEVER invoked here.
# Each single-quoted check body is a child program, not parent-shell expansion.
# shellcheck disable=SC2016
for codespaces in '' true; do
    check "repeat loading preserves retained aliases (CODESPACES=$codespaces)" "$codespaces" '
        for name in uvr uvs gosquad tls tks tt ta; do
            if alias "$name" >/dev/null 2>&1; then
                printf "Retired alias remains: %s\n" "$name" >&2
                exit 1
            fi
        done
        for name in create_tmux start_up; do
            if declare -F "$name" >/dev/null; then
                printf "Retired function remains: %s\n" "$name" >&2
                exit 1
            fi
        done
        [[ ${SQUAD_HQ_ROOT+x} != x && ${SQUAD_WORK_REPO+x} != x ]]
        for name in ga gaa gb gc gcm gcb gco gd gds gf gfp ggs ggsls ggsp gl glog gp gpf gpl grb grbi grs grss gs ghpr ghprl ghprv ghis ghiv ni nr nrd nrt py pip c myip pb h ep sb sz reload dk dkc dkps dkpsa; do
            alias "$name" >/dev/null
        done
        for name in _dev_setup_shutdown_platform sdn tsdn cancel_tsdn; do
            declare -F "$name" >/dev/null
        done
    '
done

# shellcheck disable=SC2016
check 'npm aliases preserve arguments and failures (non-forwarding mock)' '' '
    npm() { printf "<%s>" "$@"; return "${MOCK_RC:-0}"; }
    [[ $(eval "ni --save-dev") == "<install><--save-dev>" ]]
    [[ $(eval "nr \"build target\"") == "<run><build target>" ]]
    [[ $(eval "nrd -- --port 1234") == "<run><dev><--><--port><1234>" ]]
    [[ $(eval "nrt -- --watch") == "<run><test><--><--watch>" ]]
    MOCK_RC=29
    if eval "nr build" >/dev/null; then exit 1; else [[ $? -eq 29 ]]; fi
'

# shellcheck disable=SC2016
check 'git, gh and Python aliases preserve arguments (non-forwarding mocks)' '' '
    git() { printf "<%s>" "$@"; }
    gh() { printf "<%s>" "$@"; }
    python3() { printf "<%s>" "$@"; }
    [[ $(eval "gs \"path with spaces\"") == "<status><-sb><path with spaces>" ]]
    [[ $(eval "ghprl --limit 3") == "<pr><list><--limit><3>" ]]
    [[ $(eval "py \"file name.py\"") == "<file name.py>" ]]
'

# shellcheck disable=SC2016
check 'sb loads only the private Bash rc; sz refuses the wrong shell' '' '
    eval "sb"
    [[ -f $RC_LOG ]]
    IFS= read -r line < "$RC_LOG"
    [[ $line == bash-rc ]]
    [[ $(eval "sz") == *"Not in zsh"* ]]
    count=0
    while IFS= read -r line; do
        [[ $line == bash-rc ]]
        count=$((count + 1))
    done < "$RC_LOG"
    [[ $count -eq 1 ]]
'

printf '\nResults: %s passed, %s failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
