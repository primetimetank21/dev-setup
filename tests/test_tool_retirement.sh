#!/usr/bin/env bash
# Retirement regressions (#518), compatible with Bash 3.2.
# Real routers/resolvers run in a copied fixture with recording-only installers.
# Prerequisite package managers are non-forwarding stubs. Dotfiles use private
# homes and a restricted command PATH; no auth, network, or host setup runs.
# This executes reviewed source, not a hostile-code sandbox. Set TMPDIR to place
# all disposable fixtures; failures retain their exact fixture and command logs.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASH_BIN="$BASH"
[[ "$BASH_BIN" == /* && -x "$BASH_BIN" ]] || { printf 'Absolute Bash executable required\n' >&2; exit 1; }
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/dev-setup-retirement.XXXXXX")" || exit 1
PASS=0 FAIL=0
pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }
die() { fail "$1"; exit 1; }
cleanup() {
    if [[ $FAIL -eq 0 ]]; then
        if rm -rf -- "$FIXTURE" && [[ ! -e "$FIXTURE" ]]; then
            printf 'Removed owned retirement fixture: %s\n' "$FIXTURE"
        else
            printf 'ERROR: fixture cleanup failed: %s\n' "$FIXTURE" >&2
            exit 1
        fi
    else
        printf 'Failure evidence retained: %s\n' "$FIXTURE" >&2
    fi
}
trap cleanup EXIT

# All tracked current operational paths, including hidden/config files. Historical
# CHANGELOG, docs/plans, .mailmap, and the old media are deliberately not rewritten.
# Tests may name retired tools only as explicit absence/rejection regressions.
pattern='uv|squad|tmux|psmux|start_up|tank_dev|bootstrap-codespace|HQ_CLONE_TOKEN|HQ_TARGET'
GIT_OPTIONAL_LOCKS=0 git -C "$ROOT" grep -n -I -i -E "$pattern" -- \
    .tool-versions setup.sh setup.ps1 scripts config .github .devcontainer .copilot \
    README.md ARCHITECTURE.md CONTRIBUTING.md > "$FIXTURE/operational-references.txt"
audit_status=$?
if [[ $audit_status -eq 1 ]]; then
    pass 'no retired names or indirect startup/bootstrap wiring in tracked operational source'
else
    cat "$FIXTURE/operational-references.txt"
    die "operational reference audit failed (git grep exit $audit_status)"
fi

for name in uv squad-cli squad tmux psmux; do
    for path in "scripts/linux/tools/$name.sh" "scripts/windows/tools/$name.ps1" \
        "tests/fixtures/stub-tools/linux/$name.sh" "tests/fixtures/stub-tools/windows/$name.ps1"; do
        if [[ -e "$ROOT/$path" || -L "$ROOT/$path" ]]; then fail "retired installer/fixture remains: $path";
        else pass "absent: $path"; fi
    done
    out="$(sh "$ROOT/scripts/lib/read-tool-version.sh" "$name" 2>&1)"; status=$?
    if [[ $status -eq 1 && "$out" == *"tool '$name' not found in .tool-versions"* ]]; then
        pass "retired pin rejected: $name"
    else fail "unexpected pin result for $name (exit $status): $out"; fi
done

REPO="$FIXTURE/repo"
BIN="$FIXTURE/bin"
mkdir -p "$REPO/scripts/linux/tools" "$REPO/scripts/linux/lib" "$REPO/config/dotfiles" \
    "$BIN" "$FIXTURE/home" || die 'cannot create fixture layout'
cp "$ROOT/setup.sh" "$REPO/setup.sh" || die 'cannot copy root router'
cp "$ROOT/scripts/linux/setup.sh" "$REPO/scripts/linux/setup.sh" || die 'cannot copy dispatcher'
cp "$ROOT/scripts/linux/lib/"*.sh "$REPO/scripts/linux/lib/" || die 'cannot copy libraries'
cp "$ROOT/config/dotfiles/"* "$ROOT/config/dotfiles/".[!.]* "$REPO/config/dotfiles/" || die 'cannot copy dotfile templates'

# Only these reviewed utilities and explicit stubs are reachable by child scripts.
ln -s "$BASH_BIN" "$BIN/bash" || die 'cannot link selected Bash into fixture'
for tool in basename cat cp diff dirname grep ln ls readlink rm sed sort tail touch tr xargs date; do
    tool_path="$(command -v "$tool")" || die "fixture utility unavailable: $tool"
    [[ "$tool_path" == /* ]] || die "fixture utility must be absolute: $tool"
    ln -s "$tool_path" "$BIN/$tool" || die "cannot link fixture utility: $tool"
done
cat > "$BIN/uname" <<'STUB'
#!/bin/sh
[ "$#" -eq 1 ] && [ "$1" = -s ] || exit 98
printf '%s\n' "${TEST_OS:-Linux}"
STUB
cat > "$FIXTURE/deny" <<'STUB'
#!/bin/sh
printf '%s\n' "${0##*/} $*" >> "$SIDE_EFFECT_LOG"
exit 98
STUB
for tool in git curl wget npm uv squad tmux psmux sudo brew; do
    cp "$FIXTURE/deny" "$BIN/$tool" || die "cannot create denying stub: $tool"
done
chmod +x "$BIN/uname" "$BIN/git" "$BIN/curl" "$BIN/wget" "$BIN/npm" \
    "$BIN/uv" "$BIN/squad" "$BIN/tmux" "$BIN/psmux" "$BIN/sudo" "$BIN/brew"

# Names come from the real tools directory; bodies never come from installers.
# No --tools-dir override: the real default array and registry discovery are tested.
for tool in "$ROOT/scripts/linux/tools/"*.sh; do
    name="${tool##*/}"
    cat > "$REPO/scripts/linux/tools/$name" <<'STUB'
#!/bin/sh
name=${0##*/}
name=${name%.sh}
printf '%s\n' "$name" >> "$RUN_LOG"
[ "${FAIL_TOOL:-}" != "$name" ] || exit 23
STUB
done
RUN_LOG="$FIXTURE/run.log"
SIDE_EFFECT_LOG="$FIXTURE/side-effects.log"
: > "$SIDE_EFFECT_LOG"
FAIL_TOOL=''
run_setup() {
    local script="$1"
    shift
    : > "$RUN_LOG"
    (cd "$REPO" && env -i HOME="$FIXTURE/home" PATH="$BIN" CI=true \
        RUN_LOG="$RUN_LOG" SIDE_EFFECT_LOG="$SIDE_EFFECT_LOG" FAIL_TOOL="$FAIL_TOOL" \
        "$BASH_BIN" --noprofile --norc "$script" "$@") > "$FIXTURE/stdout" 2> "$FIXTURE/stderr"
    STATUS=$?
}
for entry in "$REPO/scripts/linux/setup.sh" "$REPO/setup.sh"; do
    run_setup "$entry" --list
    expected_list='auth
copilot-cli
delta
dotfiles
gh
git-hook
herdr
lazygit
nvm
pi
prereqs
zsh'
    # The root router also emits prefixed routing logs; retain every tool-name line.
    if [[ $STATUS -eq 0 && ! -s "$RUN_LOG" ]] && \
        [[ "$(grep -E '^[[:alnum:]_-]+$' "$FIXTURE/stdout")" == "$expected_list" ]]; then
        pass "retained available list, no dispatch: ${entry#"$REPO/"}"
    else fail "available list changed: ${entry#"$REPO/"}"; fi
    for flag in only skip; do
        for name in uv squad-cli squad tmux psmux; do
            for selection in "$name" "gh,$name"; do
                run_setup "$entry" "--$flag=$selection"
                if [[ $STATUS -eq 1 && ! -s "$RUN_LOG" ]] && \
                    grep -qF "Unknown tool: $name" "$FIXTURE/stdout" && \
                    grep -qF 'Available tools:' "$FIXTURE/stdout"; then
                    pass "reject before dispatch: ${entry#"$REPO/"} --$flag=$selection"
                else
                    fail "retired selection did not fail normally (exit $STATUS): --$flag=$selection"
                    cat "$FIXTURE/stdout" "$FIXTURE/stderr" "$RUN_LOG"
                fi
            done
        done
    done
done

for attempt in 1 2; do
    run_setup "$REPO/setup.sh" --non-interactive
    if [[ $STATUS -eq 0 ]] && cmp -s "$RUN_LOG" "$ROOT/tests/fixtures/baseline-tools-linux.txt"; then
        pass "recording-only default run $attempt preserves retained order"
    else fail "default run $attempt changed order or failed (exit $STATUS)"; fi
done
run_setup "$REPO/setup.sh" --only=pi,herdr,lazygit,delta,git-hook,gh,nvm
if [[ $STATUS -eq 0 && "$(cat "$RUN_LOG")" == $'nvm\ngh\ngit-hook\ndelta\nherdr\nlazygit\npi' ]]; then
    pass 'retained defaults stay ordered; opt-ins follow alphabetically'
else fail 'retained selection order changed'; fi
run_setup "$REPO/setup.sh" --skip=auth,copilot-cli
if [[ $STATUS -eq 0 && "$(cat "$RUN_LOG")" == $'prereqs\nzsh\nnvm\ngh\ndotfiles\ngit-hook' ]]; then
    pass 'retained exclusion preserves default order'
else fail 'retained exclusion changed'; fi
FAIL_TOOL=nvm
run_setup "$REPO/setup.sh" --non-interactive
if [[ $STATUS -eq 1 && "$(cat "$RUN_LOG")" == $'prereqs\nzsh\nnvm' ]]; then
    pass 'installer failure stops dispatch and propagates through root'
else fail 'installer failure was swallowed or later tools ran'; fi
FAIL_TOOL=''
run_setup "$REPO/setup.sh" --non-interactive
if [[ $STATUS -eq 0 ]] && cmp -s "$RUN_LOG" "$ROOT/tests/fixtures/baseline-tools-linux.txt"; then
    pass 'repeat run after failure does not persist a partial selection'
else fail 'repeat run after failure changed defaults'; fi

# Exercise the actual prerequisite command lists and failure propagation with
# non-forwarding package managers. Linux/WSL/macOS labels below are simulations,
# not native platform or installed-package evidence.
PREREQ_BIN="$FIXTURE/prereq-bin"
mkdir "$PREREQ_BIN" || die 'cannot create prerequisite fixture'
ln -s "$BIN/dirname" "$PREREQ_BIN/dirname"
cp "$BIN/uname" "$PREREQ_BIN/uname"
cat > "$PREREQ_BIN/grep" <<'STUB'
#!/bin/sh
[ "$#" -eq 3 ] && [ "$1" = -qi ] && [ "$2" = microsoft ] && [ "$3" = /proc/version ] || exit 98
[ "$TEST_WSL" = 1 ]
STUB
cat > "$FIXTURE/package-manager" <<'STUB'
#!/bin/sh
{
    printf '%s' "${0##*/}"
    printf '<%s>' "$@"
    printf '\n'
} >> "$PACKAGE_LOG"
# sudo only records its arguments; it NEVER invokes apt-get or another command.
exit "$PACKAGE_STATUS"
STUB
for tool in sudo brew; do cp "$FIXTURE/package-manager" "$PREREQ_BIN/$tool"; done
chmod +x "$PREREQ_BIN/grep" "$PREREQ_BIN/sudo" "$PREREQ_BIN/brew"
for platform in linux wsl macos; do
    os=Linux; wsl=0
    [[ "$platform" != wsl ]] || wsl=1
    [[ "$platform" != macos ]] || os=Darwin
    expected=$'sudo<apt-get><update><-qq>\nsudo<apt-get><install><-y><curl><git><build-essential><vim>'
    [[ "$platform" != macos ]] || expected='brew<install><curl><git><vim>'
    for attempt in 1 2; do
        : > "$FIXTURE/packages.log"
        env -i HOME="$FIXTURE/home" PATH="$PREREQ_BIN" TEST_OS="$os" TEST_WSL="$wsl" \
            PACKAGE_LOG="$FIXTURE/packages.log" PACKAGE_STATUS=0 \
            "$BASH_BIN" "$ROOT/scripts/linux/tools/prereqs.sh" > "$FIXTURE/prereqs.stdout" 2> "$FIXTURE/prereqs.stderr"
        status=$?
        if [[ $status -eq 0 && "$(cat "$FIXTURE/packages.log")" == "$expected" ]]; then
            pass "simulated $platform prerequisites run $attempt retain exact package arguments"
        else fail "simulated $platform prerequisites changed (exit $status)"; fi
    done
    : > "$FIXTURE/packages.log"
    env -i HOME="$FIXTURE/home" PATH="$PREREQ_BIN" TEST_OS="$os" TEST_WSL="$wsl" \
        PACKAGE_LOG="$FIXTURE/packages.log" PACKAGE_STATUS=41 \
        "$BASH_BIN" "$ROOT/scripts/linux/tools/prereqs.sh" > "$FIXTURE/prereqs.stdout" 2> "$FIXTURE/prereqs.stderr"
    status=$?
    expected='sudo<apt-get><update><-qq>'
    [[ "$platform" != macos ]] || expected='brew<install><curl><git><vim>'
    if [[ $status -eq 41 && "$(cat "$FIXTURE/packages.log")" == "$expected" ]]; then
        pass "simulated $platform prerequisite failure propagates and stops"
    else fail "simulated $platform prerequisite failure was not preserved"; fi
done

# Ordinary dotfile installs remain local, repeatable and completion-opt-in-only,
# even with Codespaces flags set. The source audit above blocks legacy bootstrap
# before execution; denying stubs also catch any accidental external calls.
for codespaces in '' true; do
    test_home="$FIXTURE/dotfiles-${codespaces:-local}"
    mkdir "$test_home" || die 'cannot create private dotfile HOME'
    printf '# keep custom bash config\n' > "$test_home/.bashrc"
    for attempt in 1 2; do
        (cd "$REPO" && env -i HOME="$test_home" PATH="$BIN" CODESPACES="$codespaces" \
            GITHUB_REPOSITORY=example/work-repo HQ_CLONE_TOKEN=fixture-not-a-token \
            SIDE_EFFECT_LOG="$SIDE_EFFECT_LOG" \
            "$BASH_BIN" "$REPO/config/dotfiles/install.sh") > "$FIXTURE/dotfiles.stdout" 2> "$FIXTURE/dotfiles.stderr"
        status=$?
        if [[ $status -eq 0 && -L "$test_home/.aliases" && ! -e "$test_home/.dev-setup-completion.sh" ]] && \
            cmp -s "$test_home/.zshrc" "$ROOT/config/dotfiles/.zshrc.template" && \
            grep -qF '# keep custom bash config' "$test_home/.bashrc" && \
            [[ "$(grep -c '^# --- dev-setup managed block' "$test_home/.bashrc")" == 1 ]]; then
            pass "private dotfiles run $attempt (CODESPACES=$codespaces), no implicit completion"
        else
            fail "private dotfiles run $attempt failed (exit $status)"
            cat "$FIXTURE/dotfiles.stdout" "$FIXTURE/dotfiles.stderr"
        fi
        if [[ $attempt -eq 1 ]]; then
            cp "$test_home/.bashrc" "$FIXTURE/first.bashrc"
        elif cmp -s "$test_home/.bashrc" "$FIXTURE/first.bashrc"; then
            pass "repeat dotfiles preserves exact Bash rc bytes (CODESPACES=$codespaces)"
        else fail 'repeat dotfiles changed Bash rc bytes'; fi
    done
done
if [[ ! -s "$SIDE_EFFECT_LOG" ]]; then pass 'no installer/auth/network/session commands reached denying stubs';
else fail 'unexpected external operation'; cat "$SIDE_EFFECT_LOG"; fi

# Hook-compatible ASCII source must preserve the pre-existing UTF-8 output bytes.
# Extract only reviewed definitions/constants, never the installer main body.
awk '
    /^(GREEN|YELLOW|CYAN|RESET)=/ { print; colors++ }
    /^(ok|skip|info|dry)\(\)/ { print; helpers++ }
    /^install_symlink\(\) \{/ { copying=1; links++ }
    copying { print }
    copying && /^}$/ { copying=0 }
    END { if (colors != 4 || helpers != 4 || links != 1 || copying) exit 1 }
' "$ROOT/config/dotfiles/install.sh" > "$FIXTURE/output-helpers.sh" || die 'output helper extraction failed'
mkdir "$FIXTURE/output-home" "$FIXTURE/empty-bin" || die 'cannot create output fixture'
ln -s "$FIXTURE/output-target" "$FIXTURE/output-home/existing-link"
# shellcheck disable=SC2016
env -i HOME="$FIXTURE/output-home" PATH="$FIXTURE/empty-bin" TARGET="$FIXTURE/output-target" \
    "$BASH_BIN" --noprofile --norc -c '
        set -eu
        . "$1"
        DRY_RUN=true
        readlink() { printf "%s\n" "$TARGET"; }
        ok "output fixture"
        skip "output fixture"
        info "output fixture"
        dry "output fixture"
        install_symlink "$TARGET" "$HOME/missing-link" fixture
        install_symlink "$TARGET" "$HOME/existing-link" fixture
    ' output-byte-check "$FIXTURE/output-helpers.sh" > "$FIXTURE/output.actual" 2> "$FIXTURE/output.stderr"
status=$?
{
    printf '\033[0;32m\342\234\223 output fixture\033[0m\n'
    printf '\033[0;36m\342\206\222 Already installed: output fixture\033[0m\n'
    printf '\033[1;33m  output fixture\033[0m\n'
    printf '\033[1;33m[dry-run] output fixture\033[0m\n'
    printf '\033[1;33m[dry-run] Would create symlink: %s \342\206\222 %s\033[0m\n' "$FIXTURE/output-home/missing-link" "$FIXTURE/output-target"
    printf '\033[1;33m[dry-run] Symlink already correct: %s \342\206\222 %s\033[0m\n' "$FIXTURE/output-home/existing-link" "$FIXTURE/output-target"
} > "$FIXTURE/output.expected"
if [[ $status -eq 0 && ! -s "$FIXTURE/output.stderr" ]] && cmp -s "$FIXTURE/output.expected" "$FIXTURE/output.actual"; then
    pass 'output helpers and symlink previews preserve exact UTF-8/color bytes using portable escapes'
else fail "output byte parity failed (exit $status)"; fi
if [[ -L "$FIXTURE/output-home/existing-link" && ! -e "$FIXTURE/output-home/missing-link" ]]; then
    pass 'extracted output/preview helpers leave fixture links unchanged'
else fail 'output/preview helper changed a fixture link'; fi

printf '\nResults: %s passed, %s failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
