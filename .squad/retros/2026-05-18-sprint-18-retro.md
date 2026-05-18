# Sprint 18 Retrospective -- 2026-05-18

**Theme:** Hygiene template formalization + SKILL bundling + live automation validation
**Focus:** Mandatory spawn-prompt hygiene tail template; SKILL formalization wave for history.md + changelog patterns; production validation of label automation.

## What we shipped

- #397 (Mickey): Mandatory Hygiene Tail template -- 6-item spawn-prompt checklist formalized in `.squad/templates/spawn-prompt-hygiene.md` + routing.md section added. Prevents 3 known failure modes from S17. PR #401 @ 0883c50.
- #398 (Pluto): `history-md-pre-size-check` SKILL formalized -- recurring 3-sprint pattern (S15, S16, S17) to pre-check history.md size before append. Medium confidence. PR #402 @ 8ecd0e3.
- #399 (Pluto): `changelog-fold-completeness` SKILL formalized -- recurring sprint-end pattern to verify folded entries in CHANGELOG. Medium confidence. PR #402 @ 8ecd0e3 (bundled with #398).
- #400 (Donald): sprint-end-labels.sh live production validation -- first full run on S17 closed issues/PRs. Surfaced + fixed 2 latent bugs (gh issue list --search silently excludes PRs; Windows jq CRLF breaks idempotency grep). Added Test G for CRLF regression detection. PR #403 @ f2d5a84.

Issues closed: 4 (#397, #398, #399, #400).
PRs merged: 4 (#401, #402, #403) + 3 audit/fixup PRs (#404, #406, #407) = 7 total.

## Mid-sprint audit (Jiminy-6 #404)

- Compressed ralph/history.md (15006 -> 9312 B) and scribe/history.md (14449 -> 13606 B)
- Flagged: Pluto missing inbox drop for #402; Donald missing inbox drop for #403
- 2 follow-up fixup PRs filed (#406, #407) to restore decision trail + history attribution

## What went well

- **Hygiene tail template landed cleanly and immediately effective.** PR #401 formalized Mickey's 6-item spawn template. Template embedded reference to per-SKILL docs (.squad/skills/history-md-pre-size-check/SKILL.md, .copilot/skills/ascii-docs-about-non-ascii/SKILL.md, etc.). All future spawns now mandatory-check these 6 items.
- **2-SKILL bundling pattern validated.** Pluto-7 combined `history-md-pre-size-check` + `changelog-fold-completeness` into single PR #402. Reduced PR overhead without clarity loss. Proved replicable bundling works (after S17 pilot with worktree-remove-first + gh-pr-base-develop).
- **Live production validation surfaces real bugs.** Donald's #400 production run of sprint-end-labels.sh on actual closed S17 issues/PRs found 2 bugs that 6 unit tests + S17 dry-run missed: (1) gh issue list --search API silently appends is:issue filter, excluding PRs entirely; (2) Windows jq outputs CRLF line endings that break idempotency grep guards. Both fixed + Test G added to prevent CRLF regression.
- **Decision archival policy worked.** Jiminy's #404 audit identified decision-file placement discipline issue (Pluto placed #402 decision at root instead of inbox); downstream fixups (#406, #407) restored trail. Per-sprint sprint-18.md archive accepted cleanly.

## What surprised us

- **Hygiene tail template not auto-injected into same-wave spawn prompts.** PR #401 created template; agents Pluto and Donald spawned same wave didn't see it. Downstream PRs #402, #403 were missing inbox drops + history appends because spawn prompts didn't have template embedded. Coordinator memory updated: "embed Mandatory Hygiene Tail template in EVERY spawn prompt, not just link to file."
- **Windows jq CRLF is a latent trap.** TSV parsing via `jq | tr -d '\r'` needed to compensate for Windows shell output formatting. Pattern now captured in Test G; applicable to any bash script that parses tabular output on Windows.
- **Live automation surfaces edge cases faster than dry-run.** Donald's dry-run of sprint-end-labels.sh in S17 passed; production run in S18 found both bugs immediately. Lesson: staged production validation (prod run on small data) beats dry-run-only confidence.

## Key learnings

- **NEW: Mandatory hygiene tail template is spawn-time reflex, not audit-time recovery.** All 6 items (CWD-pin, base=develop, ASCII, history.md size-check, worktree-remove-first, history append) now mandatory. Prevents preventable failures caught by Jiminy post-facto in S17. Coordinator must inject template into EVERY spawn prompt (not just link).
- **REINFORCED: 2-SKILL bundling reduces ceremony.** Pluto-7 (#402) paired related hygiene SKILLs. Replicable. Next waves can bundle up to ~3 related SKILLs per PR without losing clarity.
- **REINFORCED: Per-sprint decisions.md sub-folders working.** S17 policy applied cleanly. S18 closes with decisions.md < 11 KB (well under 51200 B gate). Inbox drain into sprint-18.md archive flowed smoothly.
- **NEW: decision-file path discipline.** Spawn prompts must explicitly say "inbox" path. Pluto-7 placed #402 at root (misplaced); S18 retro moved it to inbox/. Future: update spawn template to include explicit inbox path for decision drops.
- **NEW: ASCII purity maintained 0-non-ASCII in all S18 commits.** All file writes (sprint-18.md, retro, history appends) verified ASCII-only. Sprint-wide policy holding.

## Carry-forwards

None from S17 carry forward into S18 (all 3 from S17 retro -- mandatory hygiene tail #397, history-md-pre-size-check #398, changelog-fold-completeness #399 -- addressed and shipped in S18 Wave 1).

## Open follow-ups

- **Embed Mandatory Hygiene Tail template in EVERY spawn prompt.** S18 showed same-wave agents don't see template file link. Coordinator to inject verbatim into routing.md section for all future wave spawns.
- **20+ orphan decision files at .squad/decisions/ root** (changelog-retro-placement.md, mickey-*.md, pluto-dotfiles.md, etc.) pre-date S17 per-sprint archival policy (#371). Earl decision needed: archive into appropriate sprint-NN.md files OR keep as-is. Flagged as Open Follow-Up.
- **Release 0.9.8 decision pending.** S18 ships 3 internal hygiene items (#397, #398, #399) + 1 script bugfix (#400 with 2 bug fixes). Earl to decide: release as 0.9.8 vs defer to next sprint.

## Sprint 18 stats

- Issues closed: 4 (#397, #398, #399, #400)
- PRs merged: 7 (#401-#407; 4 work PRs + 3 audit/fixup)
- SKILLs formalized: 2 (history-md-pre-size-check medium, changelog-fold-completeness medium)
- Bugs surfaced (live validation): 2 (gh issue list --search behavior, Windows jq CRLF)
- Bugs fixed: 2 (#403 primary + #400 logic)
- Test coverage added: 1 (Test G for CRLF regression)
- Non-ASCII incidents: 0
- decisions.md final size: 10094 B (< 51200 B gate)
- scribe history.md: 13606 B (< 15360 B gate)
- Base=develop incidents: 0
- Worktree cleanup: 1/1 (100%)
