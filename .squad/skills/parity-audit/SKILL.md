---
name: "parity-audit"
description: "Audit top-level shell utilities and script-driven tests for Linux, macOS, and Windows parity requirements."
domain: "cross-platform, testing"
confidence: "medium"
source: "observed"
---

## Context

Cross-platform drift is a recurring failure mode in this repo. Top-level utility scripts and the tests that exercise them can quietly become bash-only or PowerShell-only unless parity is checked during planning and review.

Use this skill when you add, review, or audit cross-platform utilities and shell-script tests.

## Patterns

### Scope

In scope:
- Top-level `scripts/*.{sh,ps1}` utility entrypoints
- Every test file in `tests/`

Out of scope:
- `scripts/linux/`
- `scripts/windows/`

Platform-specific installers under `scripts/linux/` and `scripts/windows/` are intentionally platform-bound and do not need parity partners.

### Utility parity rule

Every cross-platform utility must have both a `.sh` and `.ps1` version, or an explicit single-platform justification recorded in a decision file.

Acceptable justification locations:
- `.squad/decisions.md`
- `.squad/decisions/*.md`

A missing partner file with no documented justification is a parity gap.

### Test runner rule

Every test that exercises shell scripts must run on Linux, macOS, and Windows runners, or have explicit per-runner exceptions documented inline as a comment in `.github/workflows/validate.yml`.

Silent omissions are not acceptable. If a test is intentionally runner-specific, document why next to the workflow entry.

### Audit recipe

Bash inventory for top-level script pairs:

```bash
repo_root="$(git rev-parse --show-toplevel)"

find "$repo_root/scripts" -maxdepth 1 -type f \( -name '*.sh' -o -name '*.ps1' \) \
  | sed "s|$repo_root/||" \
  | sed -E 's/\.(sh|ps1)$//' \
  | sort \
  | uniq -c
```

Bash parity-gap check for `scripts/` and `tests/`:

```bash
repo_root="$(git rev-parse --show-toplevel)"

comm -3 \
  <(find "$repo_root/scripts" -maxdepth 1 -type f -name '*.sh'  | sed "s|$repo_root/||" | sed 's/\.sh$//'  | sort) \
  <(find "$repo_root/scripts" -maxdepth 1 -type f -name '*.ps1' | sed "s|$repo_root/||" | sed 's/\.ps1$//' | sort)

comm -3 \
  <(find "$repo_root/tests" -maxdepth 1 -type f -name '*.sh'  | sed "s|$repo_root/||" | sed 's/\.sh$//'  | sort) \
  <(find "$repo_root/tests" -maxdepth 1 -type f -name '*.ps1' | sed "s|$repo_root/||" | sed 's/\.ps1$//' | sort)
```

PowerShell inventory for the same audit:

```powershell
$repoRoot = git rev-parse --show-toplevel

Get-ChildItem (Join-Path $repoRoot 'scripts') -File |
  Where-Object { $_.Extension -in '.sh', '.ps1' } |
  Group-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) } |
  Sort-Object Name |
  Select-Object Count, Name

Get-ChildItem (Join-Path $repoRoot 'tests') -File |
  Where-Object { $_.Extension -in '.sh', '.ps1' } |
  Group-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) } |
  Sort-Object Name |
  Select-Object Count, Name
```

PowerShell gap view:

```powershell
$repoRoot = git rev-parse --show-toplevel

$scriptSh  = Get-ChildItem (Join-Path $repoRoot 'scripts') -Filter '*.sh'  -File | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) }
$scriptPs1 = Get-ChildItem (Join-Path $repoRoot 'scripts') -Filter '*.ps1' -File | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) }
Compare-Object ($scriptSh | Sort-Object) ($scriptPs1 | Sort-Object)

$testSh  = Get-ChildItem (Join-Path $repoRoot 'tests') -Filter '*.sh'  -File | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) }
$testPs1 = Get-ChildItem (Join-Path $repoRoot 'tests') -Filter '*.ps1' -File | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) }
Compare-Object ($testSh | Sort-Object) ($testPs1 | Sort-Object)
```

Workflow audit prompt:
- Check whether every shell-script test in `tests/` is wired into Linux, macOS, and Windows validation.
- If a runner is intentionally excluded, require an inline justification comment in `validate.yml`.

### When to invoke

Invoke this skill during:
- pre-sprint research
- PR review for any new `scripts/*.{sh,ps1}` addition
- PR review for any new `tests/*.{sh,ps1}` addition

## Examples

- Adding `scripts/foo.sh` means you also add `scripts/foo.ps1`, or record a decision explaining why the utility is intentionally single-platform.
- Adding `tests/test_foo.sh` means you check `validate.yml` runner coverage and document any exception inline.
- Auditing parity starts with inventory first, then documented exceptions, then workflow coverage.

## Anti-Patterns

- Treating `scripts/linux/` and `scripts/windows/` as parity gaps. They are platform-specific by design.
- Adding a top-level `.sh` or `.ps1` utility and assuming the other platform can catch up later.
- Adding a shell-script test without checking runner coverage in `validate.yml`.
- Accepting undocumented runner exclusions or undocumented single-platform utilities.
