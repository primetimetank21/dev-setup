# Skill: Tool Version Pin Enforcement

**Confidence:** high (confirmed by issue #255 post-mortem)
**Owner:** Goofy (Cross-Platform Developer)
**Issue:** #255

---

## What

Install scripts that manage versioned tools MUST use a version-aware idempotency
check -- not a bare binary-exists check. The pinned version lives in `.tool-versions`
and is read at runtime by shared helpers.

## Why: the anti-pattern

The bare idempotency guard:

```bash
if command -v squad &>/dev/null; then
  exit 0
fi
npm install -g "@bradygaster/squad-cli"   # no version pin -- installs latest
```

...causes **silent version drift**:

- Any cached or older binary on the runner satisfies `command -v`
- The install is skipped; the version in `.tool-versions` is never enforced
- Fix PRs that bump `.tool-versions` have no effect -- the old binary stays
- CI shows green; production diverges from the declared pin

This was the root cause in issue #255: squad-cli, copilot-cli, and gh all
drifted silently across three separate install scripts.

## The canonical pattern

### 1. Pin in `.tool-versions`

```
squad-cli 0.9.4
gh        2.92.0
copilot-cli 1.0.48
```

### 2. Read pin at runtime

**Bash/POSIX:**
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQUAD_CLI_VERSION="$(sh "${SCRIPT_DIR}/../../lib/read-tool-version.sh" squad-cli)"
```

**PowerShell:**
```powershell
. "$PSScriptRoot\..\..\lib\Read-ToolVersion.ps1"
$SquadCliVersion = Get-ToolVersion -Name 'squad-cli'
```

### 3. Detect installed version

```bash
INSTALLED_VERSION=""
if command -v squad &>/dev/null; then
  INSTALLED_VERSION="$(squad --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
fi
```

```powershell
$InstalledVersion = ''
if (Get-Command squad -ErrorAction SilentlyContinue) {
    $raw = (squad --version 2>&1) | Out-String
    $m = [regex]::Match($raw, '[0-9]+\.[0-9]+\.[0-9]+')
    if ($m.Success) { $InstalledVersion = $m.Value }
}
```

### 4. Branch on comparison

```bash
if [ "${INSTALLED_VERSION}" = "${SQUAD_CLI_VERSION}" ]; then
  log_ok "squad-cli already at pinned version ${SQUAD_CLI_VERSION}"
  exit 0
fi

if [ -n "${INSTALLED_VERSION}" ]; then
  log_info "squad-cli ${INSTALLED_VERSION} installed; upgrading to pinned ${SQUAD_CLI_VERSION}..."
else
  log_info "Installing squad-cli ${SQUAD_CLI_VERSION}..."
fi
```

### 5. Install with explicit version

```bash
npm install -g "@bradygaster/squad-cli@${SQUAD_CLI_VERSION}"
```

```powershell
winget install --id GitHub.cli --version $GhVersion --silent ...
```

## Pre-commit validation checklist

Before committing any version pin, verify the package and version actually exist:

**npm packages:**
```
npm view "<package>@<version>" version
```
Must return the version number (e.g., `1.0.48`). An error means the pin is wrong.
Do NOT commit a pin that fails this check.

**Common mistake:** Copying a version number from a curl-pipe installer's internal
versioning (e.g., `gh.io/copilot-install`) and treating it as an npm version.
Curl-pipe installers use their own opaque versioning unrelated to npm. Always
verify npm package + version independently.

## Constraints and workarounds

### winget version IDs

winget catalog versions for some packages may not match semver strings used for
npm packages. For copilot CLI, winget's `GitHub.Copilot` ID installs the GitHub
Copilot for Visual Studio extension -- NOT the CLI. Use npm for copilot CLI on
all platforms.

### macOS / brew

Homebrew does not publish versioned formulae for tools like `gh`. Accept latest,
compare against the pin, and emit WARN if they differ. macOS is a secondary
target; drift is tolerable with visibility.

### Stderr warnings before version output

Some tools (squad, copilot) emit warnings on stderr before printing the version.
Always capture stderr and strip non-semver content:

```bash
squad --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
```

## Files implementing this pattern

- `scripts/linux/tools/squad-cli.sh`
- `scripts/linux/tools/copilot-cli.sh`
- `scripts/linux/tools/gh.sh`
- `scripts/windows/tools/squad-cli.ps1`
- `scripts/windows/tools/copilot.ps1`
- `scripts/windows/tools/gh.ps1`
- `scripts/lib/read-tool-version.sh`
- `scripts/lib/Read-ToolVersion.ps1`

## References

- Issue #255: Silent version drift across squad-cli, copilot-cli, and gh
- CONTRIBUTING.md section "Tool Version Pin Enforcement"
- `.tool-versions` -- single source of truth for all pinned tool versions
