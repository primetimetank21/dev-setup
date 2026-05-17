---
name: "test-harness-pattern"
description: "Bash test files in tests/*.sh use a tally-counter harness with set -uo pipefail (NOT -euo) so individual assertion failures don't abort the suite."
domain: "testing"
confidence: "medium"
source: "observed"
---

## Context

dev-setup ships several bash test suites under `tests/*.sh`. Contributors authoring
a new test (or extending an existing one) need to know two non-obvious conventions:

1. The test files deliberately use `set -uo pipefail` rather than `set -euo
   pipefail`. The `-e` flag is OFF on purpose.
2. PASS / FAIL state is tracked by tally counters; the script exits non-zero only
   after counting every assertion.

A contributor who "fixes" the missing `-e` will break the suite: the first failing
assertion will abort the script before the tally can finish, hiding the rest of
the failures from CI.

## Patterns

### The set-flags decision

| Pattern | When to use |
|---------|-------------|
| `set -uo pipefail` | Default for new bash tests. Use when the test body invokes scripts or commands that may exit non-zero outside an `if`/`||` guard (e.g., `bash setup.sh`, `bash tools/foo.sh`). |
| `set -euo pipefail` | Only acceptable when every potentially-failing command is wrapped in `if ...; then`/`else fail; fi` or `cmd || handler`. Three current files use it (`test_nvm_bootstrap.sh`, `test_precommit_hygiene.sh`, `test_shared_logging.sh`) because every assertion is grep-in-an-if. |

Rule: when in doubt, `-uo`. The tally still works either way; `-uo` is the safer
default because it lets you call subprocesses freely.

### The tally skeleton

```bash
#!/usr/bin/env bash
set -uo pipefail

PASS=0
FAIL=0
RED='\033[0;31m'
GREEN='\033[0;32m'
RESET='\033[0m'

pass() { echo -e "${GREEN}PASS${RESET}: $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${RESET}: $1"; FAIL=$((FAIL + 1)); }

# ...assertions...

echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
```

### Counter naming

Older suites (`test_aliases.sh`, `test_idempotency.sh`, `test_tool_versions.sh`,
`test_alias_parity.sh`) use uppercase `PASS` / `FAIL`. Newer suites
(`test_precommit_hygiene.sh`, `test_shared_logging.sh`) use lowercase `passed` /
`failed`. Both work. Pick one within a file; don't mix.

### Path setup boilerplate

Every bash test resolves paths relative to the repo root rather than CWD, so the
suite works regardless of where it's invoked from:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
```

`${BASH_SOURCE[0]}` is preferred over `$0` because it works when the test file is
sourced (e.g., for shared helper extraction).

### Reusable assertion helpers

When a test does the same shape of check repeatedly, wrap it in an `assert_*`
helper that tallies internally. `test_idempotency.sh` is the canonical reference:

```bash
assert_command_exists() {
  local cmd="$1"
  local msg="${2:-$cmd is on PATH}"
  if command -v "$cmd" &>/dev/null; then
    pass "$msg"
  else
    fail "$msg (command not found: $cmd)"
  fi
}
```

Helpers are file-local today. If a helper is reused across 2+ files, move it to
`tests/lib/` (matches the `scripts/{linux,windows}/lib/` source-of-truth pattern).

## Examples

### Reference files

| File | Style | Notes |
|------|-------|-------|
| `tests/test_idempotency.sh` | `-uo` + `PASS`/`FAIL` + `assert_*` helpers | Canonical complex suite. Calls tool scripts directly. |
| `tests/test_aliases.sh` | `-uo` + `PASS`/`FAIL` + tmux mock | Shows how to mock subcommands inside a tally suite. |
| `tests/test_tool_versions.sh` | `-uo` + `PASS`/`FAIL` minimal | Smallest reference; good for new contributors. |
| `tests/test_precommit_hygiene.sh` | `-euo` + `passed`/`failed` | Valid `-euo` use: every assertion is an `if grep -q`. |
| `tests/test_shared_logging.sh` | `-euo` + `passed`/`failed` | Valid `-euo` use: small file, every check guarded. |

### CHANGELOG-visible discovery PR

PR closing #237 (this skill's authoring trigger) extended CONTRIBUTING.md with
the `Test Harness Pattern` section; the prose mirrors this skill.

## Anti-Patterns

- **Adding `-e` to a tally-based suite "for safety".** This is the trap. The
  script will exit on the first `grep -q PATTERN file` that returns 1, before the
  matching `fail()` runs. The remaining tests never execute, and CI sees a
  partial run that looks like a different failure mode.
- **Tallying without exit code at the end.** A test that prints `Results: 5
  passed, 3 failed` but exits 0 will be reported as green in CI. Always end with
  `if [ "$FAIL" -gt 0 ]; then exit 1; fi`.
- **Using bash arithmetic on a pre-incremented counter under `-e`.**
  `PASS=$((PASS + 1))` when `PASS=0` returns exit code 1 (the expression value
  was 0 before increment? no -- actually the assignment exit code is fine).
  Real footgun: `((PASS++))` evaluates to the OLD value of `PASS`; when `PASS=0`,
  `((PASS++))` is `((0))` which exits 1. Under `set -e` this aborts. Use
  `PASS=$((PASS + 1))` (the form already in the suite) or `((PASS+=1))`.
- **ASCII-only matters here too.** Bash test PASS / FAIL lines render on
  contributors' terminals and CI logs. The output prefixes (`PASS`, `FAIL`,
  `[PASS]`, `[FAIL]`, `[OK]`, `[X]`) vary across files, but the surrounding code
  must remain ASCII to satisfy the pre-commit hygiene check on staged files.
- **Bash test relying on a working directory.** Use the `SCRIPT_DIR` /
  `REPO_ROOT` boilerplate. Tests that `cd` somewhere mid-run must restore the
  cwd or fail predictably.
