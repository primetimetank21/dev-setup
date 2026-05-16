# Donald -- Verification Report

**Audit Batch:** 5 findings (V-2, V-4, V-10, V-12, V-14)  
**Date:** 2026-05-04  
**Verifier:** Donald (Shell Dev)

---

## V-2: Logging consolidation

**Verdict:** CONFIRMED

**Citations:**
- `setup.sh` (root), lines 24-27: defines `log_info`, `log_ok`, `log_warn`, `log_error` as local functions
- `scripts/linux/uninstall.sh`, lines 15-22: defines `ok`, `info`, `skip` as local functions (subset of log functions)
- `scripts/linux/lib/log.sh`, lines 7-10: exposes same four functions `log_info`, `log_ok`, `log_warn`, `log_error`

**Nuance:**
The audit is correct but incomplete. The root `setup.sh` defines all four log functions and never sources `lib/log.sh`. However, `uninstall.sh` only defines *three* of the four (missing `log_error`), so it's incomplete even among the duplicates. The refactor #186 created the shared library but didn't consolidate callers. Both scripts *can* source `lib/log.sh` -- there's no circular dependency or path resolution issue (the scripts know the relative path).

**Recommended phase:** P1

**Effort estimate:** S (under 1 hr)

**Notes:**
- `setup.sh` at line 110 execs bash on `scripts/linux/setup.sh`, which already sources `lib/log.sh` (line 21). The root script's log functions never reach downstream scripts, so they're truly dead code.
- `uninstall.sh` is called independently and does use its own log functions, but inconsistently (defines ok/info/skip but not log_error, even though root setup.sh's log_error is a good pattern).
- Refactor is straightforward: (1) remove lines 24-27 from root setup.sh, add one-line source before main() call; (2) add `log_error` function to uninstall.sh or source lib/log.sh.

---

## V-4 (Linux side): macOS parity -- Homebrew guidance

**Verdict:** CONFIRMED (partial severity)

**Citations:**
- `scripts/linux/setup.sh`, lines 59-62: detects macOS, checks for brew, logs warning, returns 0 (success) if missing
- Line 61: `log_warn "Homebrew not found — install it from https://brew.sh and re-run setup"`
- Line 62: `return 0` (not exit 1)

**Nuance:**
The claim is correct, but the severity is lower than implied. The script *does* provide a URL (https://brew.sh), which is helpful. However, the downstream behavior is silent failure: if brew is missing, `brew install curl git vim tmux` (line 64) is never called, and the script continues. On a fresh macOS box without Homebrew, this means curl/git/vim/tmux are not installed, and downstream tool installers (nvm, uv, gh) will likely fail with cryptic errors rather than immediate clarity.

**Recommended phase:** P2

**Effort estimate:** S (under 1 hr)

**Notes:**
- Worst-case UX: user on macOS without Homebrew runs setup.sh, sees warning, then downstream script fails with "command not found: curl" or similar, forcing them to debug and install brew retroactively.
- Better UX: escalate to error (exit 1) or at least skip setup entirely and point to brew setup before re-running.
- Current approach is defensive (don't break on missing brew) but optimistic (assumes user has curl/git elsewhere). On stock macOS, that's not true.

---

## V-10: .aliases POSIX safety

**Verdict:** CONFIRMED

**Citations:**
- `config/dotfiles/.aliases`, line 90: `alias sb='[[ -n "$BASH_VERSION" ]] && source ~/.bashrc || echo "[sb] Not in bash — use sz"'`
- `config/dotfiles/.aliases`, line 92: `alias sz='[[ -n "$ZSH_VERSION" ]] && source ~/.zshrc || echo "[sz] Not in zsh — use sb"'`

**Nuance:**
The audit is correct: `[[ ]]` is bash/zsh-specific, not POSIX `[ ]` syntax. However, fixing just these two lines doesn't make the file POSIX-compliant. The file uses `||` and `&&` chains extensively (common in bash/zsh), and the rest of the code is already bash/zsh-idiomatic. More critically: `.aliases` is sourced only by `.zshrc.template` (line 18: `[ -f "$HOME/.aliases" ] && source "$HOME/.aliases"`), which is itself a zsh/bash config file, not pure POSIX sh. No pure-sh environment sources `.aliases`, so POSIX compliance is not a real requirement.

**Recommended phase:** P3 (not worth it)

**Effort estimate:** S (trivial code change, but pointless)

**Notes:**
- If the goal is to avoid bashisms: document that `.aliases` requires bash or zsh and don't try to force POSIX compliance.
- If the goal is pedantry: lines 90 and 92 can use `if [ -n "$BASH_VERSION" ]` instead, but the change has zero practical impact.
- Current design is correct: shell aliases are shell-specific; no need to support POSIX sh for this file.

---

## V-12: .tool-versions squad-cli pin missing

**Verdict:** CONFIRMED (but nuance on whether it matters)

**Citations:**
- `.tool-versions` (lines 1-4): pins nodejs, nvm, uv, copilot-cli (no squad-cli entry)
- `scripts/linux/tools/squad-cli.sh`, line 27: calls `npm install -g "@bradygaster/squad-cli"` (no version constraint)
- `scripts/windows/tools/squad-cli.ps1`, line 25: same, calls `npm install -g "@bradygaster/squad-cli"` (no version constraint)
- `scripts/lib/read-tool-version.sh` exists and is used by nvm.sh (line 17), uv.sh (line 20), and others

**Nuance:**
The audit is correct: squad-cli is not pinned in `.tool-versions`, and neither Linux nor Windows installer reads from it. However, there's a design question: **should** squad-cli be pinned? The difference from nvm/uv/copilot-cli is that squad-cli is the CLI for *this repo's automation*, not an external tool. Pinning a build tool can create chicken-and-egg situations (if setup.sh is running squad-cli, pinning its version is tricky). Conversely, without pinning, users on different dates may get different squad-cli versions, leading to setup behavior drift.

**Recommended phase:** P2

**Effort estimate:** M (1-3 hrs)

**Notes:**
- Decision needed from Mickey/Earl: should squad-cli be versioned separately or float to latest?
- If pinning is desired: (1) add line to `.tool-versions`; (2) update squad-cli.sh and squad-cli.ps1 to read the version; (3) update read-tool-version.sh if needed (it already handles missing tools gracefully).
- Current state (no pinning) means squad-cli is installed at latest each time setup runs, which is fine for active development but risky for reproducibility.

---

## V-14: Tests missing -e flag

**Verdict:** CONFIRMED (inconsistent, not all tests affected)

**Citations:**
- `tests/test_idempotency.sh`, line 23: `set -uo pipefail` (missing -e)
- `tests/test_alias_parity.sh`, line 19: `set -uo pipefail` (missing -e)
- `tests/test_aliases.sh`, line ~N: `set -uo pipefail` (missing -e)
- `tests/test_tool_versions.sh`: `set -uo pipefail` (missing -e)
- `tests/test_nvm_bootstrap.sh`: `set -euo pipefail` (has -e -- CORRECT)
- `tests/test_shared_logging.sh`: `set -euo pipefail` (has -e -- CORRECT)

**Nuance:**
The audit is correct for the specific files cited, but misses the inconsistency: half the test suite uses `-e`, half doesn't. Looking at test_idempotency.sh and test_alias_parity.sh, both *do* have manual error handling: they call functions like `pass()` / `fail()` that track results, and only report overall exit code at the end (see lines 32-33 and elsewhere). So the missing `-e` is *intentional* -- tests are designed to continue on assertion failure, accumulate results, then exit with a summary. This is test-harness design, not a bug.

**Recommended phase:** P2

**Effort estimate:** S (under 1 hr)

**Notes:**
- The missing `-e` is not a bug in these tests; it's a feature. Tests accumulate pass/fail counts and report at the end instead of halting on first failure.
- However, *other* tests (test_nvm_bootstrap.sh, test_shared_logging.sh) use `-euo pipefail`, which means they halt on failure. This inconsistency is confusing.
- Recommendation: either (a) document the pattern (assertion-based tests use `-uo`, exit-on-fail tests use `-euo`), or (b) standardize: move all tests to `-euo` and remove the accumulation logic if we want fail-fast behavior.
- Do not blindly add `-e` to test_idempotency.sh and test_alias_parity.sh -- that would break their test runner.

---

## Summary

**Hits:**
- V-2 (logging consolidation) is real and fixable (P1).
- V-10 (POSIX syntax) is technically true but not actionable -- `.aliases` is already bash/zsh-only by design.
- V-12 (squad-cli versioning) is real but requires a design decision on whether squad-cli should float or pin.
- V-14 (test -e flag) is real but only for certain tests; others intentionally omit `-e` for test harness design.

**Misses/Nuances:**
- V-4 (Homebrew guidance) is less severe than claimed -- script *does* provide a URL, but the downstream silent-fail UX is rough.
- V-10 and V-14 require clarification of intent before acting (not bugs, design choices).
- V-12 needs clarification on squad-cli versioning philosophy.

**Recommendation order:** V-2 (highest value, clear fix) → V-12 (needs design decision) → V-4 (nice-to-have UX) → V-10 and V-14 (skip or document).
