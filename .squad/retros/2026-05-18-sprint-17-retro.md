# Sprint 17 Retrospective -- 2026-05-18

**Theme:** SKILL formalization wave + decisions.md architecture refresh
**Focus:** Per-sprint decisions sub-folders; verification-with-retry pattern; ASCII hygiene.

## What we shipped

- #385 (Scribe): README refresh -- 12766 -> 14688 bytes (+15.1%), added agents/hooks/skills/conventions sections. PR 5a3b988.
- #386 (Pluto): 2 SKILLs formalized -- `worktree-remove-first` (medium confidence, 12+ apps) + `gh-pr-base-develop` (high confidence, codifies #368 lesson). PR 17c940b.
- #387 (Pluto): history append.
- #388 (Mickey): decisions.md gate restored -- 65737 -> 7228 bytes via per-sprint sub-folders (sprint-12.md, sprint-15.md) + Option 3+5 hybrid policy. PR 09082de.
- #389 (Donald): sprint-end label automation -- hybrid script + workflow, retry-verify pattern, formalized as `gh-label-verify-retry` SKILL, 6/6 Pester tests pass. PR 400f9ac.
- #390 (Jiminy): post-batch audit fixes -- compressed donald/history.md 15860->10236, fixed .gitignore em-dash from #389. PR 6375a49.

Issues closed: #371, #381, #382, #383, #384 (5 issues).

## What went well

- **Per-sprint decisions.md sub-folders landed cleanly.** Option 3+5 hybrid: live decisions.md holds current-sprint only; archives to sprint-NN.md on wrap. Gate met immediately (65737 -> 7228 B). Sustainable long-term.
- **gh-pr-base-develop SKILL formalization codified the prevent-#368 lesson.** High confidence justified (explicit base flag now mandatory in routing). Zero base=main incidents post-launch.
- **Verification-with-retry pattern proved reusable.** Donald's label automation (#389) pioneered re-query + exponential backoff. Now a formal SKILL; candidates for future label/state automations.
- **2-SKILLs-per-PR bundling reduced overhead.** Pluto-6 formalized 2 related SKILLs in 1 PR instead of 2. Less CI/admin, same signal. Replicable pattern.
- **Audit sweep confirmed ASCII slip in .gitignore.** Jiminy caught Donald-2's em-dash (#389 -> #390 fix) post-merge. Non-ASCII SKILL exists but not auto-enforced in spawn template.

## What surprised us

- **history.md gate breeched mid-sprint (RECURRING).** Donald-2 appended #389 history without pre-checking size. Jiminy compressed post-facto. Pattern: agents should always size-check own history.md BEFORE appending. Could be SKILL graduation candidate (reusable pre-append check). Add to spawn-prompt mandatory hygiene tail.

- **Non-ASCII slips past non-ASCII skill (REINFORCED).** ascii-docs-about-non-ascii SKILL exists (Sprint 16 #362) but is not auto-enforced in spawn-prompt template. Donald-2 wrote em-dash to .gitignore in #389; Jiminy caught + fixed in #390. Consider adding to mandatory hygiene tail alongside base=develop check.

- **NEW: SKILL formalization wave pattern works.** Bundling related SKILLs reduces ceremony. Pluto-6 (#386) proved this; expect future waves to follow 2-3 per PR bundled by domain.

- **REINFORCED: base=develop discipline held firm.** All 4 Wave 1 PRs (#385, #386, #388, #389) + Jiminy's #390 verified --base develop post-creation. New SKILL (#384) working as designed.

## Key learnings

- **NEW: Per-sprint decisions.md sub-folders.** Archive pattern: wrap sprint -> move current decisions.md to sprint-NN.md, reset live file to [] for next sprint. Eliminates unsustainable gate growth mid-sprint. Live file now <10 KB; archive grows predictably.

- **NEW: Verification-with-retry formalizes uncertainty handling.** Donald's #389 pattern (re-query after state change, retry with backoff on mismatch) is now `gh-label-verify-retry` SKILL. Applicable to any GitHub state automations.

- **RECURRING: Pre-append history.md size check missing.** Donald-2 #389 append exceeded gate; Jiminy recovered. Every append should check: if (size + new_content > 14500) then archive-fold first. Propose as SKILL.

- **RECURRING: ASCII constraints need visibility in spawn template.** Both ascii-docs-about-non-ascii SKILL and base=develop should be mandatory in spawn-prompt hygiene tail. Current template mentions them but non-enforcement shows they're not visible enough during work.

- **NEW: SKILL bundling reduces PR volume.** Pluto-6 (#386) grouped 2 related SKILLs (worktree-remove-first + gh-pr-base-develop) into 1 PR. Reduced ceremony vs 1-SKILL-per-PR pattern without losing clarity. Replicable for future waves.

## Carry-forwards

- **worktree-remove-first SKILL.** Drafted Sprint 15, finally formalized Sprint 17 (#386). Medium confidence (12+ observed applications). No blockers; landed cleanly.

## Open follow-ups

- Add pre-append history.md size-check to spawn-prompt hygiene template (prevent recurse of Donald-2 #389 pattern). Consider SKILL graduation candidate.
- Add ascii-docs-about-non-ascii + base=develop checks to mandatory hygiene tail in spawn prompts (visibility -> enforcement).
- Monitor next drift audit for history.md size-check SKILL graduation readiness (1+ sprint of observation).

## Sprint 17 stats

- Issues closed: 5 (#371, #381, #382, #383, #384)
- PRs merged: 6 (#385, #386, #387, #388, #389, #390)
- SKILLs formalized: 2 (worktree-remove-first medium, gh-pr-base-develop high; 1 re-formalized gh-label-verify-retry high)
- Base=main incidents: 0
- Non-ASCII incidents: 1 (em-dash in .gitignore, caught + fixed)
- decisions.md gate: restored (65737 -> 7228 B, per-sprint sub-folders)
