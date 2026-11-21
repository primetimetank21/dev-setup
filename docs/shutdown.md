# Shutdown helpers (Bash/Zsh)

**`sdn`** requests immediate shutdown, **`tsdn <minutes>`** schedules shutdown,
and **`cancel_tsdn`** cancels a pending shutdown system-wide (not just requests
created by these helpers). In WSL they target the **Windows host**, not just the
Linux distribution. Native Linux/macOS keep their existing commands:

| Helper | WSL (Windows host) | Native Linux | macOS |
|--------|--------------------|--------------|-------|
| `sdn` | `shutdown.exe /s /t 0` | `sudo shutdown -h now` | `sudo shutdown -h now` |
| `tsdn M` | `shutdown.exe /s /t S` (`S = M * 60`) | `sudo shutdown -h +M` | `sudo shutdown -h +M` |
| `cancel_tsdn` | `shutdown.exe /a` | `sudo shutdown -c` | `sudo killall shutdown` |

`tsdn` requires **exactly one positive decimal integer with no leading zeros**
(for example, `1` or `30`). Missing/extra arguments, zero, negatives, fractions,
and nonnumeric input fail without running a shutdown command. WSL accepts up to
**5,256,000 minutes** (315,360,000 seconds); larger values are rejected before
arithmetic. Native Linux/macOS receive the original minute string without
conversion or the Windows ceiling; their own command limits still apply.

> **Windows data-loss warning:** A positive Windows `/t` timeout implicitly
> forces applications to close, even without `/f`, and unsaved work may be lost.
> WSL timed requests emit this warning to stderr. There is no extra confirmation.
> See Microsoft's [`shutdown` reference](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/shutdown).
> A zero-timeout request is not a guarantee of instantaneous power-off.

Platform selection happens only when a helper is invoked, using `uname -s` and,
on Linux only, a successful nonempty read of `/proc/version`:

| Detection | Result |
|-----------|--------|
| Linux + case-insensitive Microsoft kernel marker | WSL, even when both WSL environment variables are absent |
| Linux + non-Microsoft kernel + `WSL_DISTRO_NAME` and `WSL_INTEROP` both unset/empty | Native Linux, even if `shutdown.exe` is on PATH |
| Linux + non-Microsoft kernel + either WSL variable nonempty | Ambiguous: diagnostic, nonzero status, no operation |
| Linux + missing/unreadable/empty/failed kernel probe | Indeterminate: diagnostic, nonzero status, no operation, regardless of WSL variables |
| Darwin | macOS; inherited WSL variables are ignored and `/proc/version` is not read |
| Unsupported OS or failed OS probe | Diagnostic, nonzero status, no operation |

Stale WSL variables on native Linux are **intentionally rejected** as ambiguous.
Establish the actual platform and correct the environment manually; the helpers
never clear variables or retry automatically. This is a **heuristic, not a
security boundary**: custom WSL kernels without the Microsoft marker are
ambiguous when WSL hints remain, but indistinguishable from native Linux when
all hints are removed. Custom kernels and nested containers are outside initial
coverage; do not assume universal or fail-safe detection.

WSL requires `shutdown.exe` on PATH and Windows-process interop enabled. The
helpers check command availability without executing a probe. Missing interop
or execution failures **never fall back to Linux shutdown**, use a hard-coded
Windows drive path, or automatically abort/reschedule. Actual command output
and exit status are preserved, including permission and cancellation failures;
not every cancellation failure means "no pending shutdown." Shell exit codes
are not interpreted as Win32 error numbers. The native PowerShell profile is
unchanged by this Bash/Zsh routing contract.

The isolated regression suite is `bash tests/test_shutdown_helpers.sh`; it
requires both Bash and Zsh (optional `--bash /absolute/path` and
`--zsh /absolute/path`). It extracts only the production helper definitions and
uses non-forwarding recording stubs, never real shutdown commands. Linux/macOS
CI includes both shells and macOS system Bash 3.2. These simulated tests do not
prove live WSL or OS-level shutdown behavior; do not validate with a live
schedule-then-cancel experiment.

This reference describes the Bash/Zsh helpers. The native [PowerShell profile implementation](../scripts/windows/tools/profile.ps1) has a separate argument/routing contract; do not assume every Bash/Zsh validation rule applies there.

[Back to the overview](../README.md)
