# Donald: Fix Idempotency Check
**Date:** 2026-04-12T01:35:00Z  
**Agent:** Donald (Shell Dev)  
**Task:** Further refine copilot-cli.sh idempotency check  
**Branch:** squad/fix-copilot-cli-alias-conflict  
**Issue:** #63

## Work Summary

Donald performed deeper analysis of the idempotency check and determined that `gh copilot --help` was still incomplete. Updated to `gh copilot -- --help` to probe the actual binary/extension, not just the wrapper/alias.

This change is critical for detecting partial installs from gh 2.89.0+ where the copilot command exists as a built-in but the extension may not be fully initialized.

## Changes Made

1. Changed idempotency check from `gh copilot --help` to `gh copilot -- --help`
2. Ensures probe reaches the actual binary, not a wrapper or alias
3. Triggers proactive re-download on gh 2.89.0+ if needed

## Technical Rationale

- **Before:** `gh copilot --help` hits the alias/wrapper first, always reports "installed"
- **After:** `gh copilot -- --help` uses `--` to force argument pass-through, probing the actual extension binary
- **Effect:** Script detects genuinely missing or broken installations and re-runs gh extension install

## Status
✅ Complete — Idempotency significantly improved, ready for re-review
