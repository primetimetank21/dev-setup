#!/usr/bin/env bash
# Actual isolated shell + PTY tests. Python 3 is a TEST-only dependency.
# --zsh-init is only for explicitly supplied local unpacked-Zsh module/fpath setup.
# CI uses the native system shells without an adapter.
set -uo pipefail
PASS=0 FAIL=0
pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }
die() { printf 'ERROR: %s\n' "$1" >&2; exit 1; }
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
BASH_PATH=/bin/bash
ZSH_PATH=$(command -v zsh || :)
ZSH_INIT=''
while [[ $# -gt 0 ]]; do
    [[ $# -ge 2 ]] || die 'each option requires a path'
    case "$1" in
        --bash) BASH_PATH=$2 ;;
        --zsh) ZSH_PATH=$2 ;;
        --zsh-init) ZSH_INIT=$2 ;;
        *) die "unknown option: $1" ;;
    esac
    shift 2
done
for shell in "$BASH_PATH" "$ZSH_PATH"; do
    [[ "$shell" == /* && -x "$shell" ]] || die 'both Bash and Zsh executable absolute paths are required'
done
[[ -z "$ZSH_INIT" || ( "$ZSH_INIT" == /* && -f "$ZSH_INIT" ) ]] || die 'invalid local Zsh adapter'
command -v python3 >/dev/null || die 'Python 3 is required for PTY tests'
mkdir -p "$ROOT/.pi-herdsman" || exit 1
if [[ ! -e "$ROOT/.pi-herdsman/.gitignore" ]]; then printf '*\n' > "$ROOT/.pi-herdsman/.gitignore"; fi
FIXTURE=$(mktemp -d "$ROOT/.pi-herdsman/completion-runtime.XXXXXX") || exit 1
trap 'if [[ "$FAIL" -eq 0 ]]; then rm -rf -- "$FIXTURE"; else printf "Failure evidence: %s\n" "$FIXTURE"; fi' EXIT
cat > "$FIXTURE/runtime.py" <<'PY'
import errno
import os
from pathlib import Path
import pty
import select
import shlex
import signal
import subprocess
import sys
import time

shell, kind, scenario, root, base, adapter, installer_bash = sys.argv[1:]
work = Path(base) / (kind + '-' + scenario)
work.mkdir()
home = work / 'home'
home.mkdir()
env = {'HOME': str(home), 'ZDOTDIR': str(home), 'INPUTRC': '/dev/null',
       'HISTFILE': '/dev/null', 'TERM': 'xterm', 'LC_ALL': 'C', 'PATH': os.environ['PATH']}
q = shlex.quote
if kind == 'zsh' and adapter:
    # Load modules before Zsh first attempts line editing, without reading any
    # other rc files. Native CI uses -df and needs no such environment adapter.
    (home / '.zshenv').write_text('. ' + q(adapter) + '\nunsetopt RCS GLOBAL_RCS\n')
installer = str(Path(root) / 'config/dotfiles/install-completion.sh')
for rc in ('.bashrc', '.zshrc'):
    (home / rc).write_text('# existing fixture configuration\n')
result = subprocess.run([installer_bash, installer], env=env, cwd=work,
                        stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=20)
assert result.returncode == 0, result.stderr.decode(errors='replace')
if scenario == 'uninstalled':
    result = subprocess.run([installer_bash, installer, '--uninstall'], env=env, cwd=work,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=20)
    assert result.returncode == 0, result.stderr.decode(errors='replace')
helper = str(home / ('.bashrc' if kind == 'bash' else '.zshrc'))
setup = ''
mode = 'vi' if 'vi' in scenario else 'emacs'
is_noop = scenario in ('disabled', 'noninteractive', 'uninstalled')
if kind == 'bash':
    setup += 'set -o ' + mode + '\n'
    if scenario.startswith('reuse'):
        setup += '''_test_provider() { COMPREPLY=(ds516-aa ds516-ab ds516-ac); }
complete -F _test_provider ds516provider
'''
    setup += '''for map in emacs-standard vi-insert; do
    bind -m "$map" '"\\C-g": backward-char'
    bind -m "$map" '"\\e[Z": "KEEP"'
done
snapshot() {
    set +o
    for map in emacs-standard vi-insert vi-command; do
        bind -m "$map" -p
        bind -m "$map" -s
    done
    complete -p
}
'''
    if scenario.startswith('unavailable'):
        # Simulation tests the availability branch, NOT native Bash 3.2 behavior.
        setup += '''bind() {
    if [ "${1:-}" = -l ]; then builtin bind -l | grep -v '^menu-complete-backward$';
    else builtin bind "$@"; fi
}
'''
    setup += 'bind -l > widgets\n'
else:
    setup += 'bindkey -' + ('v' if mode == 'vi' else 'e') + '\n'
    setup += '''_test_shift() { LBUFFER+='KEEP'; }
zle -N _test_shift
for map in emacs viins; do
    bindkey -M "$map" '^G' backward-char
    bindkey -M "$map" '^[[Z' _test_shift
done
snapshot() {
    setopt
    bindkey -lL main
    for map in emacs viins vicmd; do bindkey -M "$map"; done
}
'''
    if scenario.startswith('reuse'):
        setup += '''autoload -Uz compinit
compinit -D || exit 81
_test_provider() { compadd ds516-aa ds516-ab ds516-ac; }
compdef _test_provider ds516provider
zstyle ':completion:*' verbose yes
compinit() { print 'unexpected compinit rerun' >&2; exit 82; }
'''
    if scenario == 'security':
        insecure = work / 'insecure'
        insecure.mkdir(mode=0o777)
        insecure.chmod(0o777)
        (insecure / '_unsafe').write_text('#compdef unsafe\n')
        setup += 'fpath=(' + q(str(insecure)) + ' $fpath)\n'
        setup += 'autoload -Uz compaudit; compaudit > security-audit\n'
        setup += 'autoload -Uz compinit; compinit -D || :\n'
setup += 'snapshot > before\n'
if scenario == 'disabled':
    setup += 'export DEV_SETUP_COMPLETION=0\n'
setup += '. ' + q(helper) + '\nsnapshot > after\n'
# Sourcing twice must not disturb existing editing state or completion providers.
if not is_noop:
    setup += '. ' + q(helper) + '\nsnapshot > repeated\n'
if kind == 'zsh':
    setup += 'typeset -f compdef > compdef-state\n'
    if scenario.startswith('reuse'):
        setup += '[[ ${_comps[ds516provider]} == _test_provider ]] || exit 83\n'
        setup += "zstyle -t ':completion:*' verbose || exit 84\n"
setup += '''ds516command-aa() { printf '__COMMAND__aa\\n'; }
ds516command-ab() { printf '__COMMAND__ab\\n'; }
ds516provider() { printf '__RESULT__%s\\n' "$1"; }
PS1='__PROMPT__ '
PS2='__CONTINUE__ '
printf '__READY__\\n'
'''
startup = work / 'startup'
startup.write_text(setup)
options = ['--noprofile', '--norc'] if kind == 'bash' else (['-d'] if adapter else ['-d', '-f'])

def unrelated(lines):
    if kind == 'bash':
        # bind -p prints synthetic comments for unbound functions; these are
        # not bindings. ESC is rendered as \\M- in -p, but as \\e in -s.
        return [s for s in lines if not s.startswith(('# ', '"\\C-i":', '"\\e[Z":', '"\\M-[Z":'))]
    return [s for s in lines if not s.startswith(('"^I" ', '"^[[Z" '))]

if is_noop or scenario == 'security':
    flags = [] if scenario == 'noninteractive' else ['-i']
    result = subprocess.run([shell] + options + flags + [str(startup)], env=env,
                            cwd=work, input=b'', stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, timeout=20)
    (work / 'stdout').write_bytes(result.stdout)
    (work / 'stderr').write_bytes(result.stderr)
    assert result.returncode == 0, result.stderr.decode(errors='replace')
    if is_noop:
        assert (work / 'before').read_bytes() == (work / 'after').read_bytes(), 'noop changed state'
    else:
        assert unrelated((work / 'before').read_text().splitlines()) == unrelated((work / 'after').read_text().splitlines()), 'security case changed unrelated state'
    if kind == 'zsh':
        assert (work / 'compdef-state').read_bytes() == b'', 'noop initialized completion'
        if scenario == 'security':
            assert b'/insecure' in (work / 'security-audit').read_bytes(), 'unsafe fpath was not detected'
            assert b'initialization aborted' in result.stderr, 'compinit security was not exercised'
    sys.exit(0)

for name in ('ds516-aa', 'ds516-ab', 'ds516-ac'):
    (work / name).touch()
for name in ('ds516dir-aa', 'ds516dir-ab'):
    (work / name).mkdir()
pid, fd = pty.fork()
if pid == 0:
    os.chdir(work)
    os.execve(shell, [shell] + options + ['-i'], env)
transcript = bytearray()

def send(data):
    os.write(fd, data)

def until(token, timeout=15):
    received = bytearray()
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        if select.select([fd], [], [], 0.1)[0]:
            try:
                chunk = os.read(fd, 65536)
            except OSError as e:
                if e.errno == errno.EIO:
                    break
                raise
            if not chunk:
                break
            received.extend(chunk)
            transcript.extend(chunk)
            if token in received:
                return bytes(received)
    raise AssertionError('PTY did not produce ' + repr(token) + ': ' + repr(received))

try:
    send(('. ' + q(str(startup)) + '\n').encode())
    until(b'__READY__')
    # Only Tab and Shift+Tab entries may differ. Mode, vi command map, and all
    # other bindings must be byte-identical, even after repeated sourcing.
    before = (work / 'before').read_text(encoding='latin1').splitlines()
    after = (work / 'after').read_text(encoding='latin1').splitlines()
    assert unrelated(before) == unrelated(after), 'unrelated binding or editing mode changed'
    assert (work / 'after').read_bytes() == (work / 'repeated').read_bytes(), 'repeat changed state'
    backward = kind == 'zsh' or 'menu-complete-backward' in (work / 'widgets').read_text().splitlines()
    if not backward:
        assert [s for s in before if s.startswith('"\\e[Z":')] == [s for s in after if s.startswith('"\\e[Z":')], 'old Readline Shift+Tab changed'
    # Complete actual filenames, going forward twice then backward once.
    prefix = b'ds516provider ' if scenario.startswith('reuse') else b"printf '__RESULT__%s\\n' "
    send(prefix + b'ds516-\t\t' + (b'\x1b[Z' if backward else b'') + b'\n')
    until(b'__RESULT__ds516-aa' if backward else b'__RESULT__ds516-ab')
    if not backward:
        send(b"printf '__PRESERVED__%s\\n' value\x1b[Z\n")
        until(b'__PRESERVED__valueKEEP')
    # Native command and directory providers, not only programmable completion.
    send(b'ds516command-\t\n')
    until(b'__COMMAND__aa')
    send(b"printf '__DIRECTORY__%s\\n' ds516dir-\t\n")
    # Zsh's initialized completion may remove the auto-added slash on accept.
    until(b'__DIRECTORY__ds516dir-aa')
    # Later user bindings win; no recurring prompt-time rebinding.
    if kind == 'bash':
        send(b'''bind -m emacs-standard '"\\C-i": "LATER"'; bind -m vi-insert '"\\C-i": "LATER"'; printf '__OVERRIDE__\\n'\n''')
    else:
        send(b'''_later() { LBUFFER+='LATER'; }; zle -N _later; bindkey -M emacs '^I' _later; bindkey -M viins '^I' _later; printf '__OVERRIDE__\\n'\n''')
    until(b'__OVERRIDE__\r\n')
    send(b"printf '__LATER__%s\\n' value\t\n")
    until(b'__LATER__valueLATER')
    print('native backward widget: ' + str(backward))
finally:
    (work / 'terminal.log').write_bytes(transcript)
    # Only this exact isolated child is terminated; no process-name cleanup.
    os.close(fd)
    try:
        os.kill(pid, signal.SIGHUP)
    except ProcessLookupError:
        pass
    os.waitpid(pid, 0)
PY
for kind in bash zsh; do
    case "$kind" in
        bash) shell=$BASH_PATH; scenarios='emacs vi disabled noninteractive uninstalled unavailable unavailable-vi reuse-emacs reuse-vi' ;;
        zsh) shell=$ZSH_PATH; scenarios='emacs vi disabled noninteractive uninstalled reuse-emacs reuse-vi security' ;;
    esac
    for scenario in $scenarios; do
        if python3 "$FIXTURE/runtime.py" "$shell" "$kind" "$scenario" "$ROOT" "$FIXTURE" "$ZSH_INIT" "$BASH_PATH"; then
            pass "$kind $scenario runtime and state"
        else
            fail "$kind $scenario runtime and state"
        fi
    done
done
printf '\nResults: %s passed, %s failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
