# Decision: Architecture Entry Point and File Structure

**By:** Mickey (Lead)
**Issue:** #3
**Date:** 2026-04-07T00:00:00Z

---

## Decision

### Entry Points

Two root-level entry points — one per platform family:

- `setup.sh` — Unix (Linux, macOS, WSL). Uses `uname -s` + `/proc/version` for OS detection.
- `setup.ps1` — Windows. Uses PowerShell's `$IsWindows` builtin.

Neither entry point installs tools. They are thin routers only.

### File Structure

```
dev-setup/
├── setup.sh              # Unix entry point (router)
├── setup.ps1             # Windows entry point (router)
├── scripts/
│   ├── linux/
│   │   ├── setup.sh      # Core Linux/macOS/WSL installer
│   │   └── tools/        # One script per tool
│   └── windows/
│       └── setup.ps1     # Core Windows installer
├── config/dotfiles/      # Dotfile templates
└── .github/workflows/    # CI
```

### WSL Handling

WSL is detected by grepping `/proc/version` for "microsoft". WSL is **routed as Linux** — it gets `scripts/linux/setup.sh`, not the Windows path. WSL users have a full Linux environment; treating them as Windows would install the wrong toolset.

### Tool Script Pattern

Each tool in `scripts/linux/tools/` is a standalone bash script:
- Check if already installed → skip if so (idempotency)
- Install if missing
- `exit 0` on success or skip, `exit 1` on failure

The core `scripts/linux/setup.sh` runs them via `bash <script>` (not `source`) to keep each script isolated with its own environment.

---

## Rationale

### Why two entry points at the root?

The cold-start constraint is real: on a brand-new machine, a user needs exactly one command to remember. `bash setup.sh` is that command for Unix; `powershell -File setup.ps1` for Windows. Hiding these under `scripts/` would add friction.

### Why separate the router from the installer?

The router (`setup.sh`) needs to be stable — it's what people bookmark or put in onboarding docs. The installer (`scripts/linux/setup.sh`) will change as tools are added/removed. Keeping them separate means the public API is stable.

### Why run tool scripts via `bash <script>` not `source`?

`source` pollutes the caller's environment with any variables the tool script sets. Each tool script should be independently runnable and testable. Running via `bash` gives each tool its own subshell.

### Why no package manager abstraction layer?

Over-engineering. We support two platforms (apt/brew for Linux+macOS, winget for Windows). A package-manager abstraction adds complexity with no current payoff. If a third package manager is needed, add it directly in the relevant tool script.

---

## 2026-05-17 Sprint 13 Wave 1 -- ARCH and README accuracy fixes (#325, #326)

**By:** Mickey (Lead). **PR:** #330 against `develop`.

Two narrow doc-accuracy fixes shipped together:

- `ARCHITECTURE.md`: corrected stale `scripts/windows/auth.ps1` references (file-structure tree near line 54 and ownership map near line 505) to `scripts/windows/tools/auth.ps1`. Reflects the PR #297 move into `tools/`. Closes #325.
- `README.md`: "three hooks are active" became "four hooks are active" and added a `prepare-commit-msg` subsection between `commit-msg` and `pre-push`. Reflects PR #212 (Sprint 8-hotfix). Closes #326.
- `CHANGELOG.md`: two entries under `[Unreleased] / Fixed`.

**Related prior PRs:** #297 (auth.ps1 move into `tools/`), #212 (prepare-commit-msg hook).

**Lessons captured:**

- Batching two narrow related doc fixes (same domain, same review surface) into one PR keeps reviewer load minimal and CHANGELOG noise low. This is the 2nd time the pattern has been useful (Sprint 12 also batched two doc fixes); flagged as skill candidate if it recurs again next sprint.
- Out-of-scope observations recorded in `history.md` during a prior PR (here: Mickey's #306 entry) were the exact source of these two follow-up issues. Cheap follow-up filing beats scope creep.

**Scope note:** This topic file is broadened in practice from "Architecture Entry Point" to "ARCH and README accuracy" -- subsequent doc-accuracy fixes to the entry-point / file-structure surface should land here.
