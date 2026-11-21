# Selective-install recording

`tui-demo.gif` is a replay of actual Bash picker output from [commit d562db5](https://github.com/primetimetank21/dev-setup/commit/d562db5b3503f5322158e1d5abb428338cfdc7db), not a hand-built menu illustration. The runtime is the same as the validated retirement merge; that checkpoint changed documentation only.

## What it shows

- A real 96-column, 28-row Linux/WSL PTY running `bash --noprofile --norc setup.sh --interactive`.
- Defaults initially selected; `auth` turned off; `delta` and `lazygit` selected as opt-ins.
- `q` cancels before installation. The process exits 0; no package/auth/session command runs.
- Fifteen captured states replayed for about 11 seconds, including a two-second final hold.

## Capture boundary

The command ran from a byte-matched committed-source snapshot in a neutral temporary path, with a private HOME and non-forwarding safety stubs. All 158 snapshot files were unchanged afterward; the snapshot was then removed. No real user configuration or installed tool was changed.

Terminal output was replayed with asciinema-player 3.17.0 and captured in Chromium 149 using Playwright 1.61.1. The terminal theme is dark with the program's Quiet Accent ANSI colors. Frames were decoded and inspected after GIF encoding. This is not a physical-device capture or native Windows/macOS visual certification.

Capture dependencies are local validation tools, not part of the dev-setup installed toolset. Raw casts, frame captures, replay video and detailed provenance are retained with the local task evidence; the GIF itself is version-controlled.

## When updating it

Rerecord after changing available tools, picker ordering, controls or styling. Use the actual tested code, a disposable environment and a non-installing path; do not confirm real installer execution just to make a demo. Preserve the raw recording and source identity, verify cancellation/side-effect checks, decode the finished media, and inspect readable frames before publishing.

[Back to selective install](../../../README.md#selective-install)
