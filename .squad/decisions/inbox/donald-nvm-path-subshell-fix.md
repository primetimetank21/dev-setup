# Decision: source nvm inside npm-dependent tool scripts

**Date:** 2026-05-26  
**Author:** Donald (Copilot)  
**PR:** #436  
**Branch:** squad/fix-npm-path-nvm-subshell

## Decision

Added the standard non-interactive nvm bootstrap block to both `scripts/linux/tools/copilot-cli.sh` and `scripts/linux/tools/squad-cli.sh` immediately after `log.sh` is sourced:

```bash
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  . "$NVM_DIR/nvm.sh" --no-use
  nvm use default 2>/dev/null || true
fi
```

Also changed `scripts/linux/tools/squad-cli.sh` so a missing `npm` is treated as a skip-with-warning, not a hard failure:

- logs `WARN`
- exits `0`
- tells the operator which pinned `npm install -g` command to run manually later

## Rationale

`setup.sh` launches each tool via `bash "${tool_script}"`, so every installer runs in its own subshell. That means the PATH mutation performed by `nvm.sh` dies with the `nvm.sh` process and is not visible to later siblings like `copilot-cli.sh` or `squad-cli.sh` unless they source `nvm.sh` again themselves.

The graceful `squad-cli.sh` fallback keeps setup idempotent and consistent with `copilot-cli.sh`: if Node is still unavailable, setup should warn and continue rather than fail the whole run.

## Validation

- `shellcheck scripts/linux/tools/copilot-cli.sh scripts/linux/tools/squad-cli.sh tests/test_nvm_bootstrap.sh`
- `bash tests/test_nvm_bootstrap.sh`
- `bash tests/test_tool_versions.sh`
- Functional subshell verification with a fake `nvm.sh` confirmed both installers find `npm` only after sourcing nvm, and `squad-cli.sh` warns/returns success when npm remains unavailable.
