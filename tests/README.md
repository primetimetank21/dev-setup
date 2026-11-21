# tests/

Idempotency test suite for the `dev-setup` scripts.

## Isolated tool retirement regressions (no machine setup)

```bash
bash tests/test_tool_retirement.sh
bash tests/test_aliases.sh
bash tests/test_alias_parity.sh
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\test_tool_retirement.ps1
```

The retirement suites run the actual root/platform dispatchers in private copies
with **non-forwarding, recording-only installers**. They check the current tool
lists, normal unknown-tool rejection before dispatch, retained selection order,
exclusions, repeat runs, and failure propagation. Bash also audits tracked current
operational references (including hidden paths), simulates prerequisite package
managers, and installs dotfiles only into private homes with Codespaces flags both
unset and set. PowerShell writes only explicit private profile paths with a mocked
host query, checks fresh/repeated and legacy-block replacement, and loads generated
aliases without invoking any shutdown or session helper.

Fixtures use `TMPDIR` (Bash/Unix) or `TEMP`/`TMP` (Windows), are removed on success,
and are retained with a printed path on failure. No installed tools are removed.
These checks do not prove live package installation or native platform activation;
CI runs the suites with Linux/macOS Bash and Windows PowerShell 5.1/7. The separate
E2E workflow owns fresh-runner install/idempotency checks. Historical changelog,
design plans, author identities, and the pending replacement demo are not live
support and are excluded from the operational-source audit.

## Isolated completion tests (no machine setup)

```bash
/bin/bash tests/test_completion_install.sh
/bin/bash tests/test_completion_runtime.sh --bash /bin/bash --zsh /bin/zsh
```

These tally-based suites do **not** run `setup.sh`, source personal rc files, or
modify the real HOME. All generated homes, copied checkouts, and PTY fixtures
live under ignored `.pi-herdsman/completion-*` directories. They are removed on
success and retained with a printed path on assertion failure; local evidence
is not backed up by Git. Bash 3.2 can drive both suites. Runtime tests require
both shell executables and **Python 3** for real pseudo-terminal interaction.

- `test_completion_install.sh`: old managed-block and exact rc byte preservation
  (CRLF, backslashes, missing final newline), quoted paths, backups, missing rc
  files, repeated install/removal, linked-helper upgrades, dry-run, later user
  additions, explicit `ZDOTDIR`, and fail-before-mutation handling of malformed,
  duplicate, modified, binary, or ambiguous symlink configuration.
- `test_completion_runtime.sh`: installs the actual hook into isolated homes;
  verifies forward/backward file completion, command and directory completion,
  and later overrides using real keystrokes. Compares editing mode and unrelated
  key bindings, tests repeated sourcing, disabled/noninteractive/uninstalled
  fresh shells, reuses Zsh initialization and a custom provider, and verifies an
  insecure `compinit` is not bypassed. Tests both emacs and vi insertion modes.
- Native backward-widget availability is detected at runtime. On macOS system
  Bash 3.2, tests require forward cycling and preservation of a preexisting
  Shift+Tab macro. A separately labeled unavailable-widget simulation exercises
  that branch on modern Bash; it is **not** native Bash 3.2 compatibility evidence.

The dedicated `validate-completion` CI matrix runs these without full setup on
Linux and macOS, using `/bin/bash` (macOS 3.2) and `/bin/zsh`, plus syntax checks
and ShellCheck. CI uses no shell adapters. A developer with an explicitly
unpacked local Zsh may pass `--zsh-init /absolute/path/to/test-init.zsh` to set its
`module_path` and `fpath`; this is test-only, not a production fallback. The
harness isolates user startup files, but system `/etc/zshenv` is still trusted.
The fixtures execute reviewed repository code; they are not a hostile-code sandbox.

Zsh provider-reuse/security fixtures copy the selected shell's **standard native
function sources** into private fixture-owned files, preserving lookup precedence
but excluding site/vendor directories and compiled `.zwc` caches. Discovery
requires one standard `functions` (macOS) or `functions/Completion` (Linux) tree
containing `compinit`; missing/ambiguous resources fail rather than falling back.
Only those copies are on `fpath` when initializing completion. The real
`compinit -D` and `compaudit` run with their normal security checks: no bypass
flags, prompt acceptance, or changes to runner/global permissions.

Both reuse cases inject an insecure ambient directory, verify the native audit
rejects it, then verify the isolated `fpath` excludes it while provider integration
and PTY cycling work. The separate security case adds one intentionally insecure
directory to the isolated inputs and still requires detection and initialization
abort. This avoids depending on hosted-runner user/vendor completion permissions;
the installed shell's standard function sources remain trusted test dependencies.

## What is idempotency?

A script is **idempotent** when running it multiple times produces the same
result as running it once -- no duplicate side effects, no errors on repeat
runs. In this project, every tool installer in `scripts/linux/tools/` checks
whether the tool is already present before attempting to install it.

## Test suite: `test_idempotency.sh`

### What it tests

| # | Section | What is verified |
|---|---------|-----------------|
| 1 | **Tool script existence** | All four tool scripts (`zsh.sh`, `nvm.sh`, `gh.sh`, `copilot-cli.sh`) are present in `scripts/linux/tools/` |
| 2 | **Tool PATH verification** | `zsh`, `gh`, `nvm` (sourced), `node`, and `npm` are available after a normal install |
| 3 | **Tool script second-run** | Each tool script is re-run directly; the test asserts that it exits 0 **and** emits an "already installed" (or equivalent) message |
| 4 | **Config file integrity** | `/etc/shells` has no duplicate `zsh` entries; `~/.zshrc` has no duplicate `NVM_DIR`, `.local/bin`, or `nvm.sh` source lines |
| 5 | **Full setup.sh second-run** | The root `setup.sh` is executed a second time; the test asserts it exits 0 |

### How to run

```bash
# 1. Run setup once first
bash setup.sh

# 2. Then run the test suite
bash tests/test_idempotency.sh
```

Exit code `0` means all tests passed. Exit code `1` means at least one test
failed -- look for `[ ] FAIL` lines in the output.

### Example output

```
=== dev-setup Idempotency Test Suite ===
    Repo root: /workspaces/dev-setup

[i]  INFO: --- Tool script existence ---
[x] PASS: zsh.sh exists
[x] PASS: nvm.sh exists
[x] PASS: gh.sh exists
[x] PASS: copilot-cli.sh exists

[i]  INFO: --- Tool installation verification ---
[x] PASS: zsh is on PATH
[x] PASS: gh CLI is on PATH
[x] PASS: nvm is available (sourced from /root/.nvm)
[x] PASS: node is on PATH
[x] PASS: npm is on PATH

[i]  INFO: --- Tool script idempotency (second-run) ---
[x] PASS: zsh.sh: idempotent -- detected existing install on second run
[x] PASS: nvm.sh: idempotent -- detected existing install on second run
[x] PASS: gh.sh: idempotent -- detected existing install on second run
[x] PASS: copilot-cli.sh: no error on second run

[i]  INFO: --- Config file integrity ---
[x] PASS: /etc/shells: no duplicate zsh entry (count: 1)
[x] PASS: No duplicate NVM_DIR in ~/.zshrc (found 1 occurrence)
[x] PASS: No duplicate .local/bin in ~/.zshrc (found 1 occurrence)
[x] PASS: No duplicate nvm.sh source line in ~/.zshrc (found 1 occurrence)
[x] PASS: NVM_DIR exists: /root/.nvm

[i]  INFO: --- Full setup.sh second-run integration test ---
[x] PASS: setup.sh: second run completed without error

=======================================
 Results: 19 passed, 0 failed
=======================================
```

## Known limitations

| Limitation | Detail |
|-----------|--------|
| **nvm is a shell function** | `nvm` cannot be found via `command -v` until `$NVM_DIR/nvm.sh` is sourced. The test sources it automatically, but CI shells or non-login environments may miss it if `NVM_DIR` is unset. |
| **User-local PATH** | `~/.local/bin` is not always on `PATH` in non-login or non-interactive shells. The test prepends it for second-run tool checks. |
| **copilot-cli.sh requires `gh auth`** | If `gh` is not authenticated, `copilot-cli.sh` exits 0 with a warning rather than installing. The test accepts this as a valid idempotent outcome (no error). |
| **Requires prior install** | The test suite is designed to run *after* `setup.sh` has been run at least once. Running it on a clean machine without tools installed will fail the PATH and second-run checks. |
| **Linux/macOS only** | These tests target `scripts/linux/tools/`. There is no equivalent test for the Windows PowerShell setup yet. |
