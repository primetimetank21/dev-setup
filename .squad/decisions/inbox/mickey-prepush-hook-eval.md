### 2026-04-20: PSScriptAnalyzer pre-push hook evaluation — recommend partial adoption (PSScriptAnalyzer via pwsh only, skip PS 5.1)

**What:** Earl proposed adding PSScriptAnalyzer + PS 5.1 compatibility checks to the pre-push git hook to catch PowerShell CI failures locally before they reach GitHub Actions. After evaluating feasibility, environment constraints, and prior decisions, I recommend **partial adoption**: add PSScriptAnalyzer via `pwsh` as an advisory (warn-only) check in the pre-push hook, but **do not** attempt PS 5.1 compatibility checks locally. CI remains the authoritative gate.

**Why:**

#### Feasibility analysis

1. **PSScriptAnalyzer via `pwsh` — feasible with caveats.** The pre-push hook is POSIX shell. It can invoke `pwsh -Command "Invoke-ScriptAnalyzer ..."` if `pwsh` is installed. In GitHub Codespaces (Ubuntu), `pwsh` is not pre-installed but can be added via devcontainer features. On Windows, Git Bash runs POSIX hooks and `pwsh` is typically available. On macOS, `pwsh` is available via Homebrew. The check is realistic in environments where developers actively work on `.ps1` files.

2. **PS 5.1 compatibility — not feasible locally.** PS 5.1 is Windows-only (`powershell.exe`). Our primary dev environment is Linux Codespaces. There is no way to run `powershell.exe` (Windows PowerShell 5.1) on Linux. WSL does not expose `powershell.exe` inside the Linux environment. This check **must** remain CI-only on `windows-latest` runners. Attempting it in a POSIX hook would either always skip or always fail on Linux.

3. **Scope — changed files only.** The hook should diff against the remote tracking branch and only lint `.ps1` files in the push range, matching the pattern already used for shellcheck in the existing pre-push hook. This keeps the check fast and targeted.

4. **Graceful degradation — warn-only (advisory).** If `pwsh` or PSScriptAnalyzer is not installed, the hook should print a warning and continue (exit 0). Hard-fail would break the push workflow for every developer without `pwsh` installed — including those who only touch shell scripts. This matches the existing shellcheck pattern (`|| true`).

5. **CI remains authoritative.** The pre-push check is a developer convenience to catch the most common PSScriptAnalyzer violations early. CI's `lint-powershell` (PS 7+), `validate-ps51` (PS 5.1), and `validate-powershell` jobs remain unchanged and are the source of truth. No CI simplification.

6. **Decision reversal rationale.** The Sprint 7 decision (PSScriptAnalyzer = CI-only) was correct for a *hard gate* context. This proposal adds it as an *advisory soft check* — warn but don't block. That's a different contract. The original rationale ("requires pwsh, slow to invoke, platform-dependent — leave to CI") still holds for hard-gating. Advisory-only sidesteps the platform-dependency concern by gracefully skipping when `pwsh` is absent.

#### Constraints

- Hook must remain `#!/bin/sh` (POSIX) — no bash-isms
- PSScriptAnalyzer check runs only when both `pwsh` and the module are available
- PS 5.1 check is out of scope for the hook (CI-only)
- Check is advisory: warnings printed, exit code 0 (does not block push)
- Only `.ps1` files changed in the push are checked (not all repo `.ps1` files)

**By:** Mickey (Lead)
