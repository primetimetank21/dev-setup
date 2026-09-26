#!/usr/bin/env bash
# Isolated shutdown-helper tests. NEVER source the full aliases file or live aliases.
# Usage: bash tests/test_shutdown_helpers.sh [--bash /path/to/bash] [--zsh /path/to/zsh]
# Both shells are mandatory. The driver also supports macOS /bin/bash 3.2.
# Review this harness AND the extracted production functions before first execution.
# This isolates trusted, reviewed source; it is not a malicious-code sandbox.
set -uo pipefail

PASS=0
FAIL=0
pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }
die() { printf 'ERROR: %s\n' "$1" >&2; exit 1; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 1
BASH_PATH=/bin/bash
ZSH_PATH="$(command -v zsh || :)"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --bash|--zsh)
            [[ $# -ge 2 ]] || die "$1 requires an absolute shell path"
            case "$1" in
                --bash) BASH_PATH=$2 ;;
                --zsh) ZSH_PATH=$2 ;;
            esac
            shift 2
            ;;
        *) die "unknown argument: $1" ;;
    esac
done
for shell_path in "$BASH_PATH" "$ZSH_PATH"; do
    [[ "$shell_path" == /* && -x "$shell_path" && ! -d "$shell_path" ]] ||
        die "Bash and Zsh are both required; supply executable absolute paths with --bash/--zsh"
done
[[ -x /bin/sh ]] || die '/bin/sh is required for non-forwarding stubs'
for tool in awk cat chmod cmp cp env mkdir mktemp rm; do
    command -v "$tool" >/dev/null 2>&1 || die "required fixture tool missing: $tool"
done
ENV_PATH="$(command -v env)"
[[ "$ENV_PATH" == /* ]] || die 'env must resolve to an absolute executable'
mkdir -p "$REPO_ROOT/.pi-herdsman" || die 'cannot create fixture parent'
FIXTURE="$(mktemp -d "$REPO_ROOT/.pi-herdsman/shutdown-tests.XXXXXX")" || die 'mktemp failed'
[[ "$FIXTURE" == "$REPO_ROOT"/.pi-herdsman/shutdown-tests.* && -d "$FIXTURE" ]] ||
    die 'unexpected fixture directory'
trap 'rm -rf -- "$FIXTURE"' EXIT
mkdir "$FIXTURE/bin" "$FIXTURE/no-exe" "$FIXTURE/home" || die 'cannot create fixture directories'
DEFINITIONS="$FIXTURE/definitions.sh"

# Copy only these actual definitions, verbatim. No substitution, eval, or whole-file
# sourcing. Fail closed on missing/duplicate functions or changed closing layout.
# The reviewed functions use column-zero closing braces and indented body lines.
awk '
    /^(_dev_setup_shutdown_platform|sdn|tsdn|cancel_tsdn)\(\) \{$/ {
        if (copying) exit 1
        name = $0
        sub(/\(\).*/, "", name)
        count[name]++
        copying = 1
    }
    copying { print }
    copying && /^}$/ { copying = 0 }
    END {
        if (copying || count["_dev_setup_shutdown_platform"] != 1 ||
            count["sdn"] != 1 || count["tsdn"] != 1 || count["cancel_tsdn"] != 1) exit 1
    }
' "$REPO_ROOT/config/dotfiles/.aliases" > "$DEFINITIONS" || die 'helper extraction failed'
[[ -s "$DEFINITIONS" ]] || die 'empty helper extraction'

# Every executable on the child PATH is a copy of this stand-in. Even sudo only
# records; it NEVER executes its arguments. Probe reads are limited to the exact
# production cat /proc/version call and never consult the host kernel.
cat > "$FIXTURE/stand-in" <<'STUB' || die 'cannot write stand-in'
#!/bin/sh
set -u
name=${0##*/}
case "$name" in
    uname|cat)
        printf '%s\000' "$name" "$#" "$@" >> "$TEST_PROBES" || exit 98
        case "$name" in
            uname)
                [ "$#" -eq 1 ] && [ "$1" = -s ] || exit 98
                printf '%s' "$TEST_OS"
                exit "$TEST_OS_STATUS"
                ;;
            cat)
                [ "$#" -eq 1 ] && [ "$1" = /proc/version ] || exit 98
                case "$TEST_KERNEL_MODE" in
                    ok) printf '%s' "$TEST_KERNEL" ;;
                    empty) : ;;
                    missing) printf 'fixture: /proc/version missing\n' >&2; exit 1 ;;
                    unreadable) printf 'fixture: /proc/version permission denied\n' >&2; exit 1 ;;
                    error) printf '%s' "$TEST_KERNEL"; exit 74 ;;
                    *) exit 98 ;;
                esac
                ;;
        esac
        ;;
    shutdown.exe|sudo|shutdown|killall)
        # NUL fields retain exact argument boundaries, including empty arguments,
        # whitespace and shell metacharacters. Count disambiguates multiple calls.
        printf '%s\000' "$name" "$#" "$@" >> "$TEST_OPERATIONS" || exit 98
        [ -z "$TEST_OP_OUT" ] || printf '%s\n' "$TEST_OP_OUT"
        [ -z "$TEST_OP_ERR" ] || printf '%s\n' "$TEST_OP_ERR" >&2
        exit "$TEST_OP_STATUS"
        ;;
    *) exit 98 ;;
esac
STUB
for name in uname cat sudo shutdown killall shutdown.exe; do
    cp "$FIXTURE/stand-in" "$FIXTURE/bin/$name" || die "cannot copy recording stub: $name"
    chmod +x "$FIXTURE/bin/$name" || die "cannot enable recording stub: $name"
    if [[ "$name" != shutdown.exe ]]; then
        cp "$FIXTURE/stand-in" "$FIXTURE/no-exe/$name" || die "cannot copy missing-exe fixture: $name"
        chmod +x "$FIXTURE/no-exe/$name" || die "cannot enable missing-exe fixture: $name"
    fi
done

cat > "$FIXTURE/runner.sh" <<'RUNNER' || die 'cannot write child runner'
# This runner uses only Bash/Zsh builtins and the extracted definitions.
set -u
case "$TEST_SHELL_KIND" in
    bash) [ -n "${BASH_VERSION:-}" ] || exit 98 ;;
    zsh) [ -n "${ZSH_VERSION:-}" ] || exit 98 ;;
    *) exit 98 ;;
esac
# env -i clears exported functions, WSL hints, ENV/BASH_ENV, shell options, etc.
# Bash uses --noprofile --norc; Zsh uses -df and an empty HOME/ZDOTDIR. Zsh still
# reads the host /etc/zshenv: that trusted system file must not defeat isolation.
# Abort if startup changed PATH or command resolution, before loading helpers.
unalias -a
assert_isolation() {
    [ "$PATH" = "$TEST_BIN" ] || exit 98
    for required in sudo shutdown killall uname cat; do
        [ "$(command -v "$required")" = "$TEST_BIN/$required" ] || exit 98
        [ -x "$TEST_BIN/$required" ] || exit 98
    done
    if [ "$TEST_HAS_EXE" = yes ]; then
        [ "$(command -v shutdown.exe)" = "$TEST_BIN/shutdown.exe" ] || exit 98
        [ -x "$TEST_BIN/shutdown.exe" ] || exit 98
    else
        ! command -v shutdown.exe >/dev/null 2>&1 || exit 98
    fi
}
assert_isolation
unset WSL_DISTRO_NAME WSL_INTEROP
case "$TEST_HINTS" in
    none) : ;;
    empty) export WSL_DISTRO_NAME='' WSL_INTEROP='' ;;
    distro) export WSL_DISTRO_NAME=fixture-distro ;;
    interop) export WSL_INTEROP=/fixture/interop ;;
    both) export WSL_DISTRO_NAME=fixture-distro WSL_INTEROP=/fixture/interop ;;
    *) exit 98 ;;
esac
[ -f "$1" ] && [ -s "$1" ] || exit 98
# shellcheck disable=SC1090
. "$1" || exit 98
shift
for required in _dev_setup_shutdown_platform sdn tsdn cancel_tsdn; do
    typeset -f "$required" >/dev/null || exit 98
done
assert_isolation
[ ! -s "$TEST_OPERATIONS" ] && [ ! -s "$TEST_PROBES" ] || exit 98
printf 'loaded\n' > "$TEST_LOADED" || exit 98
case "${1:-}" in
    --load) exit 0 ;;
    sdn|tsdn|cancel_tsdn) "$@"; exit $? ;;
    *) exit 98 ;;
esac
RUNNER

# Expected logs use the same documented NUL wire format, not the implementation.
expect_operation() {
    : > "$FIXTURE/expected-operations" || die 'cannot reset expected operations'
    if [[ $# -gt 0 ]]; then
        local command_name=$1
        shift
        printf '%s\000' "$command_name" "$#" "$@" > "$FIXTURE/expected-operations" || die 'cannot write expected operation'
    fi
}
expect_probes() {
    : > "$FIXTURE/expected-probes" || die 'cannot reset expected probes'
    case "$1" in
        linux)
            printf '%s\000' uname 1 -s cat 1 /proc/version > "$FIXTURE/expected-probes" || die 'cannot write expected probes'
            ;;
        os) printf '%s\000' uname 1 -s > "$FIXTURE/expected-probes" || die 'cannot write expected probe' ;;
        none) : ;;
        *) die 'invalid expected probe kind' ;;
    esac
}
reset_case() {
    OS=Linux
    OS_STATUS=0
    KERNEL='Linux version 6.6.0-native'
    KERNEL_MODE=ok
    HINTS=none
    HAS_EXE=yes
    OP_STATUS=0
    OP_OUT=''
    OP_ERR=''
    EXPECT_OUT=''
    expect_operation
    expect_probes linux
}
run_case() {
    local label="$SHELL_KIND: $1" expected_status=$2 expected_error=$3
    shift 3
    local bin="$FIXTURE/bin" actual_status
    [[ "$HAS_EXE" == yes ]] || bin="$FIXTURE/no-exe"
    : > "$FIXTURE/operations" || die 'cannot reset operation log'
    : > "$FIXTURE/probes" || die 'cannot reset probe log'
    : > "$FIXTURE/loaded" || die 'cannot reset load marker'
    "$ENV_PATH" -i PATH="$bin" HOME="$FIXTURE/home" ZDOTDIR="$FIXTURE/home" LC_ALL=C \
        TEST_BIN="$bin" TEST_HAS_EXE="$HAS_EXE" TEST_HINTS="$HINTS" TEST_SHELL_KIND="$SHELL_KIND" \
        TEST_OS="$OS" TEST_OS_STATUS="$OS_STATUS" TEST_KERNEL="$KERNEL" TEST_KERNEL_MODE="$KERNEL_MODE" \
        TEST_OP_STATUS="$OP_STATUS" TEST_OP_OUT="$OP_OUT" TEST_OP_ERR="$OP_ERR" \
        TEST_OPERATIONS="$FIXTURE/operations" TEST_PROBES="$FIXTURE/probes" TEST_LOADED="$FIXTURE/loaded" \
        "$SHELL_PATH" "${SHELL_OPTIONS[@]}" "$FIXTURE/runner.sh" "$DEFINITIONS" "$@" \
        > "$FIXTURE/stdout" 2> "$FIXTURE/stderr"
    actual_status=$?
    # An absent load marker is an isolation/setup failure, not an expected helper
    # failure. Stop rather than proceeding with a possibly broken fixture.
    [[ "$(cat "$FIXTURE/loaded")" == loaded ]] || die "$label: isolation/definition-load gate failed (status $actual_status)"
    if [[ "$actual_status" -eq "$expected_status" ]]; then pass "$label status";
    else fail "$label status: expected $expected_status, got $actual_status"; fi
    if cmp -s "$FIXTURE/expected-operations" "$FIXTURE/operations"; then pass "$label exact operations";
    else fail "$label exact operations"; fi
    if cmp -s "$FIXTURE/expected-probes" "$FIXTURE/probes"; then pass "$label exact probes";
    else fail "$label exact probes"; fi
    : > "$FIXTURE/expected-stdout" || die 'cannot reset expected stdout'
    : > "$FIXTURE/expected-stderr" || die 'cannot reset expected stderr'
    if [[ -n "$EXPECT_OUT" ]]; then printf '%s\n' "$EXPECT_OUT" > "$FIXTURE/expected-stdout" || die 'cannot write expected stdout'; fi
    if [[ -n "$expected_error" ]]; then printf '%s\n' "$expected_error" > "$FIXTURE/expected-stderr" || die 'cannot write expected stderr'; fi
    if cmp -s "$FIXTURE/expected-stdout" "$FIXTURE/stdout"; then pass "$label stdout";
    else fail "$label stdout"; fi
    if cmp -s "$FIXTURE/expected-stderr" "$FIXTURE/stderr"; then pass "$label stderr";
    else fail "$label stderr"; fi
}

WARNING='tsdn: warning: a positive Windows timeout forces applications to close; unsaved work may be lost.'
AMBIGUOUS='shutdown helpers: ambiguous platform: Linux kernel lacks Microsoft marker but WSL_DISTRO_NAME or WSL_INTEROP is set; verify the platform and correct the environment manually'
KERNEL_ERROR='shutdown helpers: unable to read a nonempty /proc/version; platform is indeterminate'
OS_ERROR='shutdown helpers: unable to detect OS with uname -s'
INTEROP_ERROR='shutdown helpers: WSL requires shutdown.exe on PATH and Windows interop enabled'
INPUT_ERROR='tsdn: usage: tsdn <minutes> (one positive decimal integer, no leading zeros)'
LIMIT_ERROR='tsdn: WSL delay must not exceed 5256000 minutes'

# Shared matrix assertions call only the public production helpers. The selector
# is exercised transitively, so routing must stay correct through each entrypoint.
check_route() {
    local label=$1 route=$2
    case "$route" in
        wsl) expect_operation shutdown.exe /s /t 0 ;;
        linux|macos) expect_operation sudo shutdown -h now ;;
        *) die 'unknown expected route' ;;
    esac
    run_case "$label immediate" 0 '' sdn
    if [[ "$route" == wsl ]]; then
        expect_operation shutdown.exe /s /t 120
        run_case "$label timed" 0 "$WARNING" tsdn 2
    else
        expect_operation sudo shutdown -h +2
        run_case "$label timed" 0 '' tsdn 2
    fi
    case "$route" in
        wsl) expect_operation shutdown.exe /a ;;
        linux) expect_operation sudo shutdown -c ;;
        macos) expect_operation sudo killall shutdown ;;
    esac
    run_case "$label cancel" 0 '' cancel_tsdn
}
check_blocked() {
    local label=$1 diagnostic=$2
    expect_operation
    run_case "$label immediate" 1 "$diagnostic" sdn
    run_case "$label timed" 1 "$diagnostic" tsdn 2
    run_case "$label cancel" 1 "$diagnostic" cancel_tsdn
}

for SHELL_KIND in bash zsh; do
    case "$SHELL_KIND" in
        bash) SHELL_PATH=$BASH_PATH; SHELL_OPTIONS=(--noprofile --norc) ;;
        zsh) SHELL_PATH=$ZSH_PATH; SHELL_OPTIONS=(-df) ;;
    esac
    reset_case
    expect_probes none
    run_case 'definition loading does nothing' 0 '' --load

    # Positive kernel evidence is sufficient even without interop environment.
    for marker in 'Linux version 4.4.0-Microsoft' 'Linux version 5.15.0-microsoft-standard-WSL2' 'Linux version 6.6.0-MiCrOsOfT'; do
        for hints in none empty distro interop both; do
            reset_case; KERNEL=$marker; HINTS=$hints
            check_route "WSL $marker hints=$hints" wsl
        done
    done
    # Release-blocking native regression: Windows executable presence is irrelevant.
    for hints in none empty; do
        for executable in yes no; do
            reset_case; HINTS=$hints; HAS_EXE=$executable
            check_route "native Linux hints=$hints exe=$executable" linux
        done
    done
    for hints in distro interop both; do
        reset_case; HINTS=$hints
        check_blocked "conflicting Linux hints=$hints" "$AMBIGUOUS"
    done
    for mode in missing unreadable empty error; do
        for hints in none empty distro interop both; do
            reset_case; KERNEL_MODE=$mode; HINTS=$hints
            # Even partial Microsoft output from a failed cat is not evidence.
            KERNEL='Linux version Microsoft'
            check_blocked "kernel $mode hints=$hints" "$KERNEL_ERROR"
        done
    done
    for hints in none empty distro interop both; do
        reset_case; OS=Darwin; HINTS=$hints; KERNEL_MODE=error
        expect_probes os
        check_route "Darwin hints=$hints ignores kernel" macos
        for unsupported in FreeBSD CYGWIN_NT-10.0 ''; do
            reset_case; OS=$unsupported; HINTS=$hints
            expect_probes os
            check_blocked "unsupported OS=$unsupported hints=$hints" "shutdown helpers: unsupported OS: $unsupported"
        done
        # Failed uname must not trust even otherwise valid output.
        for failed_os in Linux Darwin ''; do
            reset_case; OS=$failed_os; OS_STATUS=71; HINTS=$hints
            expect_probes os
            check_blocked "failed uname output=$failed_os hints=$hints" "$OS_ERROR"
        done
    done

    # Input grammar is identical on all supported platforms, including set -u.
    for route in wsl linux macos; do
        reset_case
        case "$route" in wsl) KERNEL='Linux Microsoft' ;; macos) OS=Darwin ;; esac
        expect_probes none
        run_case "$route missing minutes under nounset" 1 "$INPUT_ERROR" tsdn
        run_case "$route extra minutes" 1 "$INPUT_ERROR" tsdn 1 2
        run_case "$route extra empty argument" 1 "$INPUT_ERROR" tsdn 1 ''
        # Injection-shaped inputs must remain literal, never shell-expanded.
        # shellcheck disable=SC2016
        for bad in '' 0 -1 01 00 +1 1.5 abc '1 2' ' 1' '1 ' $'1\n' '1;shutdown.exe /s /t 0' '$(shutdown.exe /s /t 0)' '`sudo shutdown -h now`' '1*2'; do
            run_case "$route invalid [$bad]" 1 "$INPUT_ERROR" tsdn "$bad"
        done
    done
    reset_case; KERNEL='Linux Microsoft'
    expect_operation shutdown.exe /s /t 60
    run_case 'WSL one minute' 0 "$WARNING" tsdn 1
    expect_operation shutdown.exe /s /t 315360000
    run_case 'WSL maximum minutes' 0 "$WARNING" tsdn 5256000
    expect_operation
    for oversized in 5256001 9999999 10000000 999999999999999999999999999999999999999999999999999999999999999999999999; do
        run_case "WSL oversized $oversized" 1 "$LIMIT_ERROR" tsdn "$oversized"
    done
    for route in linux macos; do
        reset_case
        if [[ "$route" == macos ]]; then OS=Darwin; expect_probes os; fi
        for minutes in 1 5256001 999999999999999999999999999999999999999999999999999999999999; do
            expect_operation sudo shutdown -h "+$minutes"
            run_case "$route unconverted minutes $minutes" 0 '' tsdn "$minutes"
        done
    done

    reset_case; KERNEL='Linux Microsoft'; HAS_EXE=no
    check_blocked 'WSL executable absent: no native fallback' "$INTEROP_ERROR"
    # Statuses are shell process results, NOT inferred Win32 error numbers.
    # All commands preserve output and failures, including cancellation. sudo's
    # non-forwarding behavior also means simulated native failures stay harmless.
    for route in wsl linux macos; do
        for result in 0 1 126 127; do
            reset_case; OP_STATUS=$result
            OP_OUT='fixture command stdout'; EXPECT_OUT=$OP_OUT
            case "$result" in
                0) OP_ERR='fixture command diagnostic' ;;
                1) OP_ERR='fixture cancellation/command failure' ;;
                126) OP_ERR='fixture permission denied' ;;
                127) OP_ERR='fixture Windows interop disabled / command unavailable' ;;
            esac
            case "$route" in
                wsl) KERNEL='Linux Microsoft'; expect_operation shutdown.exe /s /t 0 ;;
                linux) expect_operation sudo shutdown -h now ;;
                macos) OS=Darwin; expect_probes os; expect_operation sudo shutdown -h now ;;
            esac
            run_case "$route immediate command result=$result" "$result" "$OP_ERR" sdn
            if [[ "$route" == wsl ]]; then
                expect_operation shutdown.exe /s /t 120
                run_case "$route timed command result=$result" "$result" "$WARNING"$'\n'"$OP_ERR" tsdn 2
                expect_operation shutdown.exe /a
            else
                expect_operation sudo shutdown -h +2
                run_case "$route timed command result=$result" "$result" "$OP_ERR" tsdn 2
                if [[ "$route" == macos ]]; then expect_operation sudo killall shutdown;
                else expect_operation sudo shutdown -c; fi
            fi
            run_case "$route cancellation result=$result" "$result" "$OP_ERR" cancel_tsdn
        done
    done
done

printf '\nResults: %s passed, %s failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
