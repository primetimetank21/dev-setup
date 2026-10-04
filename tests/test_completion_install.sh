#!/usr/bin/env bash
# Isolated completion-only lifecycle tests, also run with macOS /bin/bash 3.2.
set -uo pipefail
PASS=0 FAIL=0
pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }
die() { printf 'ERROR: %s\n' "$1" >&2; exit 1; }
check() { local label=$1; shift; if "$@"; then pass "$label"; else fail "$label"; fi; }
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
mkdir -p "$ROOT/.pi-herdsman" || exit 1
# Disposable local fixtures must remain ignored, including in fresh CI clones.
if [[ ! -e "$ROOT/.pi-herdsman/.gitignore" ]]; then printf '*\n' > "$ROOT/.pi-herdsman/.gitignore"; fi
FIXTURE=$(mktemp -d "$ROOT/.pi-herdsman/completion-install.XXXXXX") || exit 1
trap 'if [[ "$FAIL" -eq 0 ]]; then rm -rf -- "$FIXTURE"; else printf "Failure evidence: %s\n" "$FIXTURE"; fi' EXIT
BASH_PATH=${BASH:-/bin/bash}
# A repository path AND a HOME containing shell metacharacters must remain literal.
REPO="$FIXTURE/repo ' \$literal"
mkdir -p "$REPO"
cp "$ROOT/config/dotfiles/"*completion.sh "$REPO/" || exit 1
INSTALLER="$REPO/install-completion.sh"
new_home() {
    HOME_DIR="$FIXTURE/$1 home ' \$literal"
    mkdir "$HOME_DIR" || die 'cannot create HOME fixture'
    ZSH_DIR=$HOME_DIR
}
run() {
    env -i PATH="$PATH" HOME="$HOME_DIR" ZDOTDIR="$ZSH_DIR" \
        "$BASH_PATH" "$INSTALLER" "$@" > "$FIXTURE/stdout" 2> "$FIXTURE/stderr"
}
snapshot() {
    (cd "$HOME_DIR" && { find . -print; find . -type f -exec cksum {} \; -o -type l -exec readlink {} \;; } | LC_ALL=C sort)
}
assert_rejected() {
    local label=$1 before after
    shift
    before=$(snapshot)
    if run "$@"; then fail "$label rejected"; else pass "$label rejected"; fi
    after=$(snapshot)
    check "$label mutation-free" test "$before" = "$after"
}

new_home existing
# Preserve a real old DevSetup managed block without running the general installer.
printf '# custom\r\nexport KEEP_ME="yes"\n' > "$HOME_DIR/.bashrc"
sed -n '/^# --- dev-setup managed block /,/^# --- end dev-setup managed block ---/p' \
    "$ROOT/config/dotfiles/.zshrc.template" >> "$HOME_DIR/.bashrc"
printf '\n# literal backslash \\ and no final newline' >> "$HOME_DIR/.bashrc"
cp "$HOME_DIR/.bashrc" "$HOME_DIR/.zshrc"
cp "$HOME_DIR/.bashrc" "$FIXTURE/original"
printf 'do not touch\n' > "$HOME_DIR/.gitconfig"
printf 'do not touch\n' > "$HOME_DIR/.bash_profile"
before=$(snapshot)
check 'existing dry-run succeeds' run --dry-run
check 'existing dry-run has zero mutations' test "$before" = "$(snapshot)"
check 'install succeeds with quoted paths and no final newline' run
check 'helper is a literal correct link' test "$(readlink "$HOME_DIR/.dev-setup-completion.sh")" = "$REPO/completion.sh"
for rc in .bashrc .zshrc; do
    backups=("$HOME_DIR/$rc.dev-setup-completion.bak."*)
    check "$rc exact pre-edit backup" cmp -s "$FIXTURE/original" "${backups[0]}"
    check "$rc preserved original byte prefix" cmp -s "$FIXTURE/original" <(head -c "$(wc -c < "$FIXTURE/original")" "$HOME_DIR/$rc")
done
check 'unrelated dotfile untouched' test "$(cat "$HOME_DIR/.gitconfig")" = 'do not touch'
check 'bash_profile untouched' test "$(cat "$HOME_DIR/.bash_profile")" = 'do not touch'
before=$(snapshot)
check 'repeat install succeeds' run
check 'repeat install changes no bytes or backups' test "$before" = "$(snapshot)"
printf '\n# upgraded helper fixture\n' >> "$REPO/completion.sh"
check 'helper upgrade succeeds' run
check 'helper upgrade leaves hooks/backups unchanged' test "$before" = "$(snapshot)"
check 'helper link exposes upgraded source' cmp -s "$REPO/completion.sh" "$HOME_DIR/.dev-setup-completion.sh"
check 'uninstall dry-run succeeds' run --uninstall --dry-run
check 'uninstall dry-run is mutation-free' test "$before" = "$(snapshot)"
# Later user additions must survive uninstall, not be rolled back from a backup.
printf '# later user addition\n' >> "$HOME_DIR/.bashrc"
cat "$FIXTURE/original" > "$FIXTURE/expected"
printf '\n# later user addition\n' >> "$FIXTURE/expected"
check 'uninstall succeeds' run --uninstall
check 'uninstall preserves later additions with a line separator' cmp -s "$FIXTURE/expected" "$HOME_DIR/.bashrc"
check 'uninstall restores missing final newline' cmp -s "$FIXTURE/original" "$HOME_DIR/.zshrc"
check 'uninstall removes only helper link' test ! -L "$HOME_DIR/.dev-setup-completion.sh"
before=$(snapshot)
check 'repeat uninstall succeeds' run --uninstall
check 'repeat uninstall changes nothing' test "$before" = "$(snapshot)"

# Removing a hook must not fuse executable user configuration across its
# separator. Only these innocuous assignment fixtures are sourced, in children
# with an empty environment and no personal startup files.
for prefix_kind in no_newline newline empty; do
    for suffix_kind in eof text separated; do
        new_home "boundary-$prefix_kind-$suffix_kind"
        expected_a=1
        case "$prefix_kind" in
            no_newline) printf 'export A=1' > "$FIXTURE/prefix" ;;
            newline) printf 'export A=1\n' > "$FIXTURE/prefix" ;;
            empty) : > "$FIXTURE/prefix"; expected_a='' ;;
        esac
        expected_b=2
        case "$suffix_kind" in
            eof) : > "$FIXTURE/suffix"; expected_b='' ;;
            text) printf 'export B=2\n' > "$FIXTURE/suffix" ;;
            separated) printf '\nexport B=2\n' > "$FIXTURE/suffix" ;;
        esac
        cp "$FIXTURE/prefix" "$HOME_DIR/.bashrc"
        cp "$FIXTURE/prefix" "$HOME_DIR/.zshrc"
        label="boundary $prefix_kind/$suffix_kind"
        check "$label install" run
        cat "$FIXTURE/suffix" >> "$HOME_DIR/.bashrc"
        cat "$FIXTURE/suffix" >> "$HOME_DIR/.zshrc"
        cp "$FIXTURE/prefix" "$FIXTURE/expected"
        if [[ "$prefix_kind/$suffix_kind" == no_newline/text ]]; then
            printf '\n' >> "$FIXTURE/expected"
        fi
        cat "$FIXTURE/suffix" >> "$FIXTURE/expected"
        check "$label uninstall" run --uninstall
        for rc in .bashrc .zshrc; do
            check "$label $rc exact bytes" cmp -s "$FIXTURE/expected" "$HOME_DIR/$rc"
            # shellcheck disable=SC2016
            check "$label $rc separate assignments" env -i PATH="$PATH" HOME="$HOME_DIR" ZDOTDIR="$ZSH_DIR" \
                "$BASH_PATH" --noprofile --norc -c \
                '. "$1" && [ "${A-}" = "$2" ] && [ "${B-}" = "$3" ]' \
                completion-rc-check "$HOME_DIR/$rc" "$expected_a" "$expected_b"
        done
    done
done

new_home missing
before=$(snapshot)
check 'missing rc dry-run succeeds' run --dry-run
check 'missing rc dry-run creates nothing' test "$before" = "$(snapshot)"
check 'missing rc uninstall succeeds' run --uninstall
check 'missing rc uninstall creates nothing' test "$before" = "$(snapshot)"
check 'missing rc install succeeds' run
check 'both missing rc files created' test -f "$HOME_DIR/.zshrc"
check 'fresh install makes no fake backup' test "$(find "$HOME_DIR" -name '*.bak.*' | wc -l | tr -d ' ')" = 0
check 'fresh uninstall succeeds' run --uninstall
check 'new bashrc is left empty, not deleted' test ! -s "$HOME_DIR/.bashrc"
check 'new zshrc is left empty, not deleted' test ! -s "$HOME_DIR/.zshrc"

new_home zdotdir
ZSH_DIR="$HOME_DIR/zsh dir"
mkdir "$ZSH_DIR"
printf 'untouched\n' > "$HOME_DIR/.zshrc"
printf 'export ZDOTDIR="do not execute me"\n' > "$HOME_DIR/.zshenv"
check 'explicit ZDOTDIR install succeeds' run
check 'HOME zshrc remains untouched with ZDOTDIR' test "$(cat "$HOME_DIR/.zshrc")" = untouched
check 'effective ZDOTDIR rc created' test -f "$ZSH_DIR/.zshrc"
check 'explicit ZDOTDIR uninstall succeeds' run --uninstall
before=$(snapshot)
if env -i PATH="$PATH" HOME="$HOME_DIR" "$BASH_PATH" "$INSTALLER" > "$FIXTURE/stdout" 2>&1; then
    fail 'unresolved zshenv rejected'
else pass 'unresolved zshenv rejected'; fi
check 'unresolved zshenv changes nothing' test "$before" = "$(snapshot)"
ZSH_DIR=relative
assert_rejected 'relative ZDOTDIR'
ZSH_DIR="$HOME_DIR/absent"
assert_rejected 'missing ZDOTDIR'

# Lexical directory spellings must not hide a symlink from preflight. Keep
# both the link and its real target inside HOME so snapshots cover every edit.
case_number=0
printf '# preserve directory-boundary fixture\n' > "$FIXTURE/path-original"
for path_suffix in '/' '///' '/.' '/./' '/child/..' '/child/../'; do
    case_number=$((case_number + 1))
    new_home "zdotdir-real-$case_number"
    mkdir -p "$HOME_DIR/real-zsh/child"
    cp "$FIXTURE/path-original" "$HOME_DIR/.bashrc"
    cp "$FIXTURE/path-original" "$HOME_DIR/real-zsh/.zshrc"
    ZSH_DIR="$HOME_DIR/real-zsh$path_suffix"
    before=$(snapshot)
    check "real ZDOTDIR $path_suffix preview" run --dry-run
    check "real ZDOTDIR $path_suffix preview mutation-free" test "$before" = "$(snapshot)"
    check "real ZDOTDIR $path_suffix install" run
    check "real ZDOTDIR $path_suffix uninstall" run --uninstall
    check "real ZDOTDIR $path_suffix preserves bashrc" cmp -s "$FIXTURE/path-original" "$HOME_DIR/.bashrc"
    check "real ZDOTDIR $path_suffix preserves zshrc" cmp -s "$FIXTURE/path-original" "$HOME_DIR/real-zsh/.zshrc"
done
for path_suffix in '' '/' '///' '/.' '/./' '/child' '/child/.' '/./child//' '/child/..' '/../real-zsh'; do
    case_number=$((case_number + 1))
    for mode in install dry-run uninstall uninstall-dry-run; do
        new_home "zdotdir-link-$case_number-$mode"
        mkdir -p "$HOME_DIR/real-zsh/child"
        ln -s "$HOME_DIR/real-zsh" "$HOME_DIR/zsh-link"
        ZSH_DIR="$HOME_DIR/real-zsh"
        case "$path_suffix" in '/child'|'/child/.'|'/./child//') ZSH_DIR="$ZSH_DIR/child" ;; esac
        cp "$FIXTURE/path-original" "$HOME_DIR/.bashrc"
        cp "$FIXTURE/path-original" "$ZSH_DIR/.zshrc"
        case "$mode" in
            uninstall*) check "seed real ZDOTDIR for $path_suffix $mode" run ;;
        esac
        ZSH_DIR="$HOME_DIR/zsh-link$path_suffix"
        [[ -d "$ZSH_DIR" ]] || die 'symlink variant must resolve to an existing directory'
        case "$mode" in
            install) set -- ;;
            dry-run) set -- --dry-run ;;
            uninstall) set -- --uninstall ;;
            uninstall-dry-run) set -- --uninstall --dry-run ;;
        esac
        assert_rejected "symlink ZDOTDIR $path_suffix $mode" "$@"
    done
done

# Use an actual generated valid block as a fixture, then corrupt it in ways
# whose safe response is rejection of the entire install AND uninstall.
new_home hook_source
check 'generate valid hook fixture' run
cp "$HOME_DIR/.bashrc" "$FIXTURE/valid-hook"
for kind in truncated duplicate modified stray_end no_separator no_final_newline missing_markers; do
    new_home "$kind"
    printf '# first target must stay unchanged\n' > "$HOME_DIR/.bashrc"
    case "$kind" in
        truncated) head -n 3 "$FIXTURE/valid-hook" > "$HOME_DIR/.zshrc" ;;
        duplicate) cat "$FIXTURE/valid-hook" "$FIXTURE/valid-hook" > "$HOME_DIR/.zshrc" ;;
        modified) sed 's/! -r/! -f/' "$FIXTURE/valid-hook" > "$HOME_DIR/.zshrc" ;;
        stray_end) printf '# <<< dev-setup completion v1 <<<\n' > "$HOME_DIR/.zshrc" ;;
        no_separator) tail -n +2 "$FIXTURE/valid-hook" > "$HOME_DIR/.zshrc" ;;
        no_final_newline) printf '%s' "$(cat "$FIXTURE/valid-hook")" > "$HOME_DIR/.zshrc" ;;
        missing_markers) sed '/dev-setup completion/d' "$FIXTURE/valid-hook" > "$HOME_DIR/.zshrc" ;;
    esac
    assert_rejected "$kind hook"
    before=$(snapshot)
    if run --uninstall; then fail "$kind uninstall rejected"; else pass "$kind uninstall rejected"; fi
    check "$kind uninstall mutation-free" test "$before" = "$(snapshot)"
done
for kind in symlink_rc dangling_rc directory_rc user_helper foreign_helper nul_rc; do
    new_home "$kind"
    printf '# first target unchanged\n' > "$HOME_DIR/.bashrc"
    case "$kind" in
        symlink_rc) printf '# linked\n' > "$HOME_DIR/realrc"; ln -s "$HOME_DIR/realrc" "$HOME_DIR/.zshrc" ;;
        dangling_rc) ln -s "$HOME_DIR/absent" "$HOME_DIR/.zshrc" ;;
        directory_rc) mkdir "$HOME_DIR/.zshrc" ;;
        user_helper) printf '# mine\n' > "$HOME_DIR/.dev-setup-completion.sh" ;;
        foreign_helper) ln -s "$HOME_DIR/foreign" "$HOME_DIR/.dev-setup-completion.sh" ;;
        nul_rc) printf '# binary\000content\n' > "$HOME_DIR/.zshrc" ;;
    esac
    assert_rejected "$kind"
done
if [[ "$EUID" -ne 0 ]]; then
    new_home permissions
    printf '# preserve first target\n' > "$HOME_DIR/.bashrc"
    printf '# read-only target\n' > "$HOME_DIR/.zshrc"
    chmod 400 "$HOME_DIR/.zshrc"
    assert_rejected 'read-only rc'
    chmod 600 "$HOME_DIR/.zshrc"
    ZSH_DIR="$FIXTURE/unsearchable"
    mkdir "$ZSH_DIR"
    chmod 200 "$ZSH_DIR"
    assert_rejected 'unsearchable ZDOTDIR'
    chmod 700 "$ZSH_DIR"
else
    printf 'SKIP: permission-bit rejection cases require a non-root user\n'
fi
new_home no_zdotdir_env
check 'unset ZDOTDIR without zshenv uses HOME' env -i PATH="$PATH" HOME="$HOME_DIR" \
    "$BASH_PATH" "$INSTALLER" --dry-run

printf '\nResults: %s passed, %s failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
