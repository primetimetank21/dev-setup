# Agent guide

This is the repository entry point for coding agents. Human installation instructions live in [README.md](README.md); the contributor workflow is maintained in [CONTRIBUTING.md](CONTRIBUTING.md). Keep coordination outside the repository rather than adding an embedded agent framework.

## Before editing

- Read applicable nested instructions, inspect the target checkout, branch and existing changes, and preserve work you do not own.
- Start each feature branch from current `develop`, using `{type}/{issue-number}-{slug}`. Do not fork another feature branch or commit directly on `develop`/`main`.
- Keep one bounded issue per PR. Feature PRs target `develop`; release cuts go from `develop` to `main`. Use regular merge commits, never squash.
- Follow the owner's execution and publication authority. Do not infer permission to push, merge, release, install software or change a live machine from a plan or passing tests.
- Use Conventional Commits. AI-authored commits must contain exactly one `Co-authored-by: Copilot <198982749+Copilot@users.noreply.github.com>` trailer; preserve the configured human author.
- If working as a delegated editor, leave changes unstaged/uncommitted for the coordinating owner.

## Source map

| Concern | Source of truth |
|---|---|
| OS routing | [`setup.sh`](setup.sh), [`setup.ps1`](setup.ps1) |
| Unix selection/default order and dispatch | [`scripts/linux/setup.sh`](scripts/linux/setup.sh) |
| Windows registry, aliases, default order and dispatch | [`scripts/windows/setup.ps1`](scripts/windows/setup.ps1) |
| Individual installers | [`scripts/linux/tools/`](scripts/linux/tools/), [`scripts/windows/tools/`](scripts/windows/tools/) |
| Picker state and ordered selection | [`scripts/linux/lib/tui.sh`](scripts/linux/lib/tui.sh), [`scripts/windows/lib/tui.ps1`](scripts/windows/lib/tui.ps1) |
| Version pins and readers | [`.tool-versions`](.tool-versions), [`scripts/lib/`](scripts/lib/) |
| Unix dotfiles and aliases | [`config/dotfiles/`](config/dotfiles/) |
| Windows profile writing | [`scripts/windows/tools/profile.ps1`](scripts/windows/tools/profile.ps1) |
| Regression and native CI contracts | [`tests/README.md`](tests/README.md), [workflows](.github/workflows/) |

Use [ARCHITECTURE.md](ARCHITECTURE.md) for the deeper implementation map. Files under `docs/plans/` are historical design inputs; verify their issue/revision state before treating them as unfinished work.

## Preserve these contracts

- Default order is dependency-sensitive. Selected defaults retain that order; selected opt-ins follow alphabetically. Selecting a tool does not automatically add its prerequisites.
- Unix tool files can be opt-in without joining `DEFAULT_TOOLS`. Windows tools must be registered; preserve the `copilot-cli` alias for the canonical `copilot` entry.
- Unknown selections fail before dispatch. Listing/help, cancellation and an empty confirmed selection must not install tools. CI/headless guards still apply to explicit interactive requests.
- Retain Bash 3.2 compatibility and its line-input picker fallback. `.aliases` is Bash/Zsh code, not POSIX `sh`.
- Retain Windows PowerShell 5.1 and StrictMode compatibility. Linux `pwsh` or a command named `powershell` is not proof of native PS5.1 behavior.
- Versioned installers use the shared pin readers and version-aware guards, not a bare executable-presence check. See the [pinning contract](CONTRIBUTING.md#tool-version-pin-enforcement).
- Keep helpers in their canonical libraries. Preserve exit codes, noninteractive behavior and expected-failure `$LASTEXITCODE` handling.
- Keep changed PowerShell, shell, Markdown and YAML sources ASCII-clean; retain `.gitattributes` line endings. Preserve runtime output when escaping glyphs.
- Completion is a separate opt-in with its own ownership/backup rules. Do not enable it through ordinary setup or bypass Zsh's completion security audit.
- Profile updates may touch existing user text. Preserve the canonical managed-block boundaries and add explicit LF/CRLF, repeat-write and unrelated-content regressions. Current ASCII profile writes are not an arbitrary-Unicode preservation guarantee.

## Safe validation

Inspect test setup/teardown first. Use a private HOME/USERPROFILE and temp/cache tree for execution; retain failing evidence. Never use the real machine's setup, uninstall, auth, shutdown or session commands as smoke tests. `--non-interactive` still installs defaults.

Run relevant maintained checks from the repository root:

| Change | Focused checks |
|---|---|
| Tool selection / retirement | `bash tests/test_tool_retirement.sh`; `pwsh -NoProfile -File tests/test_tool_retirement.ps1`; both `test_setup_flags` suites |
| Picker | `bash tests/test_tui_bash.sh`; `pwsh -NoProfile -File tests/test_tui_pwsh.ps1` |
| Aliases | `bash tests/test_aliases.sh`; `bash tests/test_alias_parity.sh` |
| Ordered default fixtures | `bash scripts/dev/regenerate-baseline-fixtures.sh --check` |
| Completion | `bash tests/test_completion_install.sh`; `bash tests/test_completion_runtime.sh` |
| Shutdown helpers | `bash tests/test_shutdown_helpers.sh` (non-forwarding stubs only) |

Completion runtime and shutdown suites require both Bash and Zsh. Report missing tools rather than weakening guards or calling a partial run a pass. Run relevant syntax checks, ShellCheck and native hosted CI as well.

`tests/test_idempotency.sh` and the full `tests/test_windows_setup.ps1` include machine-changing setup. Use CI or a deliberately disposable machine, not a normal workstation. Profile load-only checks use a disposable startup-scope runspace: a nested function scope does not reproduce Windows `AllScope` alias behavior.

For docs, check links/anchors and compare claims against current source. For visible changes, inspect actual tested output; label the source revision, environment and limitations. A rewritten description or generated preview is not execution evidence.

## Delivery

Review the final diff and relevant validation, including native Windows/macOS results when affected. Keep original failures and state what was newly tested versus reused. Do not bypass failing checks. The existing solo-owner review exception is documented in [CONTRIBUTING.md](CONTRIBUTING.md#branch-protection); it does not waive CI.

Report the resulting commit, exact branch/checkout, publication state, evidence and any remaining limits. Keep README concise; extend the canonical reference instead of duplicating a second manual here.
