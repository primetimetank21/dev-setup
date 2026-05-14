# Decision: Gitconfig editor — literal value + override comment

**Issue:** #184
**Agent:** Pluto (Config Engineer)
**Date:** 2025-07-14

## Context

`config/dotfiles/.gitconfig.template` had `editor = ${EDITOR:-vim}` in `[core]`. Git does not invoke a shell when reading its config — this string was used literally as the editor command, which fails on every machine.

## Options Considered

- **Option A:** Replace with `editor = vim` — simple literal, works everywhere.
- **Option B:** Replace with `editor = vim` AND add a comment showing how to override.

## Decision

**Option B** — literal `vim` default with an inline comment: `# Override with: git config --global core.editor <your-editor>`.

## Rationale

- `vim` is guaranteed installed by both Linux and Windows setup scripts.
- A bare literal gives no guidance to users who prefer a different editor. The comment is zero-cost but high-value discoverability.
- This follows the Pluto principle: sensible defaults with clear escape hatches.

## Outcome

Template updated. README table updated to match. No other gitconfig shell-expansion patterns found in the template.
