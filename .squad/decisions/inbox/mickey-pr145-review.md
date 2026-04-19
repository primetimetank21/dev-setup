# Decision: Adopt strip+re-inject pattern for managed config blocks

**Date:** 2026-04-19
**Author:** Mickey (Lead)
**Context:** PR #145 review (Issue #144)

## Decision

All managed config blocks (e.g., `# BEGIN dev-setup profile` / `# END dev-setup profile`) must use the **strip + re-inject** pattern instead of **skip if sentinel present**. This ensures re-running setup always converges to the latest managed content.

## Rationale

The old skip pattern silently dropped new aliases/functions for users who ran setup before those features were added. The strip+re-inject pattern preserves user content outside the markers while always injecting the current block.

## Applies To

- `Write-PowerShellProfile` in `scripts/windows/setup.ps1`
- Any future managed block injection (Linux shell configs, etc.)
