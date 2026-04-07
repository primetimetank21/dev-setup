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
