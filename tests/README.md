# tests/

Idempotency test suite for the `dev-setup` scripts.

## What is idempotency?

A script is **idempotent** when running it multiple times produces the same
result as running it once — no duplicate side effects, no errors on repeat
runs. In this project, every tool installer in `scripts/linux/tools/` checks
whether the tool is already present before attempting to install it.

## Test suite: `test_idempotency.sh`

### What it tests

| # | Section | What is verified |
|---|---------|-----------------|
| 1 | **Tool script existence** | All five tool scripts (`zsh.sh`, `uv.sh`, `nvm.sh`, `gh.sh`, `copilot-cli.sh`) are present in `scripts/linux/tools/` |
| 2 | **Tool PATH verification** | `zsh`, `gh`, `uv`, `nvm` (sourced), `node`, and `npm` are available after a normal install |
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
failed — look for `❌ FAIL` lines in the output.

### Example output

```
=== dev-setup Idempotency Test Suite ===
    Repo root: /workspaces/dev-setup

ℹ  INFO: --- Tool script existence ---
✅ PASS: zsh.sh exists
✅ PASS: uv.sh exists
✅ PASS: nvm.sh exists
✅ PASS: gh.sh exists
✅ PASS: copilot-cli.sh exists

ℹ  INFO: --- Tool installation verification ---
✅ PASS: zsh is on PATH
✅ PASS: gh CLI is on PATH
✅ PASS: uv is on PATH (~/.local/bin)
✅ PASS: nvm is available (sourced from /root/.nvm)
✅ PASS: node is on PATH
✅ PASS: npm is on PATH

ℹ  INFO: --- Tool script idempotency (second-run) ---
✅ PASS: zsh.sh: idempotent — detected existing install on second run
✅ PASS: uv.sh: idempotent — detected existing install on second run
✅ PASS: nvm.sh: idempotent — detected existing install on second run
✅ PASS: gh.sh: idempotent — detected existing install on second run
✅ PASS: copilot-cli.sh: no error on second run

ℹ  INFO: --- Config file integrity ---
✅ PASS: /etc/shells: no duplicate zsh entry (count: 1)
✅ PASS: No duplicate NVM_DIR in ~/.zshrc (found 1 occurrence)
✅ PASS: No duplicate .local/bin in ~/.zshrc (found 1 occurrence)
✅ PASS: No duplicate nvm.sh source line in ~/.zshrc (found 1 occurrence)
✅ PASS: NVM_DIR exists: /root/.nvm

ℹ  INFO: --- Full setup.sh second-run integration test ---
✅ PASS: setup.sh: second run completed without error

═══════════════════════════════════════
 Results: 21 passed, 0 failed
═══════════════════════════════════════
```

## Known limitations

| Limitation | Detail |
|-----------|--------|
| **nvm is a shell function** | `nvm` cannot be found via `command -v` until `$NVM_DIR/nvm.sh` is sourced. The test sources it automatically, but CI shells or non-login environments may miss it if `NVM_DIR` is unset. |
| **uv PATH** | `uv` installs to `~/.local/bin`, which is not always on `PATH` in non-login or non-interactive shells. The test prepends it explicitly. |
| **copilot-cli.sh requires `gh auth`** | If `gh` is not authenticated, `copilot-cli.sh` exits 0 with a warning rather than installing. The test accepts this as a valid idempotent outcome (no error). |
| **Requires prior install** | The test suite is designed to run *after* `setup.sh` has been run at least once. Running it on a clean machine without tools installed will fail the PATH and second-run checks. |
| **Linux/macOS only** | These tests target `scripts/linux/tools/`. There is no equivalent test for the Windows PowerShell setup yet. |
