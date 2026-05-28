# Jiminy's History

## Core Context

- **Project:** dev-setup - Replicable setup scripts for Dev Containers and Codespaces
- **Owner:** Earl Tankard, Jr., Ph.D.
- **Universe:** Disney Classic
- **Role:** Squad Hygiene Auditor (reviewer-gate)
- **Joined:** 2026-05-16
- **Charter:** `.squad/agents/jiminy/charter.md`
- **Model:** `claude-opus-4.6` (premium - reviewer-gate role)

## Day-1 context (summary; full hand-off at 2026-05-16 hire)

Hired 2026-05-16 to close 5 recurring squad-hygiene gaps Earl caught manually: (1) branch ancestry bleed (Sprint 7, 3x), (2) squash merges (Sprint 2/3, Ralph), (3) uncommitted histories (recurring -- Coordinator forgets Scribe), (4) rogue file paths (Verifier batch 2026-05-16 -- Source of Truth Hierarchy), (5) stale `squad/*` branches post-sprint (now Ralph EOS). Standing directives: caveman speak, em-dashes / non-ASCII FORBIDDEN in PS literals (CP1252 0x94 trap), ALL merges regular (no squash), branches from `develop` only, EOS branch cleanup mandatory, bad commit messages hard-reject, Verifier batches use SoT-Hierarchy paths only. Roster at hire: Mickey lead, Donald, Goofy, Pluto, Chip, Scribe, Ralph, Jiminy + Doc (hired 2026-05-16). Open issues at hire: 19 filed 2026-05-16 (#221-#239); P0s = #221 (nvm.ps1 path), #222 (tag hygiene 0.1.0-0.8.0), #239 (E2E CI smoke). No first task -- Jiminy auto-runs on Coordinator return-to-user.

## Learnings

> Re-compressed 2026-05-17 (W2 fold) per #319 gate. Sprint 13+ entries kept verbatim; older summarized. (W1 fold re-compress prior.)

- **2026-05-16 -- Audit runs 1-3 (summary).** First-audit baseline: clean tree, 10 pre-Sprint-5 main-direct commits accepted as historical, 2 rogue files cleaned, duplicate log dirs reconciled to singular `.squad/log/`, Scribe got Learnings section. Post-retro audit #2: 1 minor SKILL.md size finding + 1 false-positive label flag. Hygiene retro shipped 4 items (pre-spawn-checklist skill, squad-history-check CI gate, PR template, 6 standing rules). Post-batch audit #3 (4-PR sprint #243-#246): 4 findings (type-label, PR body, area-label, tmux assertion).
- **2026-05-16 to 2026-05-18 -- Sprint 10 audits.** Mid-sprint: Doc history.md modified (deferred to Scribe), `bradygaster-squad-sdk-0.9.4.tgz` rogue (PR #280: `*.tgz` to .gitignore + delete). Gap: Coordinator manual dispatch vs charter "auto-trigger after 3+ batches". EOS: clean tree, 4 known inbox drops pending Scribe drain, Mickey PR #274 missing history.md entry, 6 stale `squad/*` remote branches (Ralph EOS scope).
- **2026-05-19 -- Sprint 11 Wave 1 + session-end audits (first under #293 SOP).** All 11 lanes clean across PRs #296-#298 (Mickey #229, Goofy #230, Pluto #233). Session-end + bonus PRs #299/#301/#302: clean, `Jiminy clear`. Pattern: `gh pr merge --delete-branch` ghost-branch recurrence 75%, tracked as #300.
- **2026-05-17 -- Sprint 12 Wave 1 audits.** Closed #300 (Option A, 6-for-6 clean post-filing #299/#301/#302/#303/#311/#312); Ralph EOS `git push --delete` fallback retained. Post-batch audit after 4 merges (#313/#314/#315/#316): 11-lane clean, label gap on #317 flagged. Verdict: `0 fixes, 1 minor flag`.
- **2026-05-17 -- Sprint 12 Wave 2 post-batch audit.** 3-agent batch (Mickey #310/PR #321, Donald #237/PR #320, Goofy #235 NOT_PLANNED Case B). Findings: (i) **CRITICAL worktree-isolation violation by Mickey** -- inbox drop landed in MAIN checkout instead of `dev-setup-310`; 2nd distinct write-to-wrong-CWD event same run. Root cause: dispatch prompt didn't pin CWD; tooling resolved against process CWD. Donald's parallel spawn wrote correctly -- non-deterministic. Remediation drop filed. (ii) **MEDIUM pre-commit ASCII-scan scope gap** -- `hooks/pre-commit` Check 2 globs only `*.ps1`; ARCH/README/CONTRIBUTING have 200+ non-ASCII hits (em-dash U+2014, box-drawing U+2500/U+2502/U+251C/U+2514, smart-arrow U+2192). Filed as #322. (iii) Auto-fixed: PR #321 + #320 full label sets, `go:yes` removed from closed #235. Verdict: `3 fixes, 2 flags`.
- **2026-05-17 -- Sprint 12 session-end audit (develop `5dfc476`).** All 9 Sprint 12 issues closed across 3 waves + 2 fold PRs (10 PRs: #313/#314/#315/#316/#318/#320/#321/#323/#324). Tree clean, 0 worktree orphans, 4-5 stale `origin/squad/*` tracking refs (Ralph EOS). Label state: 8 squad:* present, `squad:scribe` MISSING (#319 gap). PR labels: only #320/#321 carry full set among Sprint 12 merges -- process gap. History-tails: ALL agents compliant. Skills: `label-hygiene` + `test-harness-pattern` template-compliant; `abstraction-threshold` not formalized. **Scribe inbox-drain bug surfaced:** decisions.md grew 44473->57253 B (drain content done) but 4 inbox files NOT deleted. CHANGELOG `[Unreleased]`: 9 entries -- 0.9.2 cut justified.
- **Lesson (Scribe inbox-drain bug):** When folding inbox decisions, the per-topic-file `git add` AND `git rm -- decisions/inbox/*.md` MUST land in the SAME commit so drain is atomic with merge. Forward-fix expectation for next Scribe cycle (PR #319 spec; re-tested in Sprint 13 W1 fold).
- **Lesson (squad: label set incomplete):** Standard label set covers 8 engineering agents but omits `squad:scribe`. Service-role follow-ups force routing miss. Recommend next label sweep create `squad:scribe` (and audit `squad:ralph` usage; precedent exists for service-role labels).
- **Recurring incident references preserved:** worktree-isolation (Sprint 4 race condition + Sprint 12 W2 CWD-resolution variant), ASCII scope gap (#322, `*.ps1`-only pre-commit), CP1252 byte 0x94 trap in PowerShell string literals, `autocrlf` and `AllScope` alias hazards, atomic-drain (PR #323 bug).
- **2026-05-18 -- Sprint 17 Wave 1 post-batch audit.** AUTO-FIXED: (1) donald/history.md 15860B over gate -- compressed to 10236B + archive; (2) .gitignore em-dash U+2014 from PR #389 -- replaced with `--`. All other lanes clean.

## Sprint 13-16 Audits (compressed 2026-05-27 -- gate breach prevention)

- **S13 W1 (2026-05-17):** Formalized `worktree-remove-first` skill (#317, PR #331). 5-of-5 proven merge sequence. CONTRIBUTING.md + CHANGELOG updated. Clean.
- **S13 W1 Post-Batch:** PRs #330-#332. 0 auto-fixes, 3 flags (doc roster, jiminy history over-gate 19852B, stale remote). GO for W2.
- **S13 W2 Post-Batch:** PRs #334-#335 (ASCII sweep + hook glob). 3 histories over gate -- Scribe fold. Mickey dogfood incident (hook blocked own commit). 1 auto-fix, 6 flags. GO for 0.9.3.
- **S13 EOS:** main @ edc67e2, develop @ a930540. 9 PRs, 5 issues. PASS (1 stale-remote CONCERN). GO.
- **S14 EOS:** 0.9.4, main @ 008f166. Doc history compressed 13023->12200B. 60+ legacy non-ASCII .md CONCERNs. PASS.
- **S15 EOS:** 0.9.5, main @ 49545ad. Inbox drained. decisions.md 60270B over threshold. PASS with CONCERNs.
- **S16 EOS:** 0.9.6, main @ 10d203f. DIRTY -- pluto history 15694B over gate, 3 undrained inbox files, squash policy mismatch (6 PRs). Blocked pending Scribe action.

### Sprint 18 W1 Post-Batch Audit (jiminy-6, 2026-05-18)

- Compressed ralph/history.md 15006->9312 B + scribe/history.md 14449->13606 B. PR #404 -> develop. Flagged: pluto+donald missing inbox drops + history trail entries for #402/#403. All other checks PASS.

- **2026-05-27 -- Grill #441 v2:** REVISE (AC#1/3 missing, $PROFILE unescalated, cleanup untested).

### 441-v4-revision (jiminy-7, 2026-05-27)

- **Session:** 441-v4-revision
- **Task:** Revise plan #441 from v3 to v4; patch 6 holes surfaced in Pluto/Chip/Doc grills.
- **Patches applied:**
  - P1 (Pluto BLOCKING): Filled foreach loop body with explicit strip regex + `Set-Content` + `Write-Info` log.
  - P2 (Pluto BLOCKING): Wrapped all algorithm code in `Write-PowerShellProfile { }` with dot-source safety comment.
  - P3 (Chip HIGH): GG-7 mock now uses `& $env:ComSpec /c "exit 1"` to propagate `$LASTEXITCODE = 1` at global scope.
  - P4 (Chip SS-2): `skip` replaced with `if/Write-Host/return`; `$PROFILE = $path` moved inside Test-Scenario body.
  - P5 (Chip MEDIUM): Section 5 header documents mock-per-test redefinition and Test-Scenario child-scope model.
  - P6 (Chip MEDIUM): GG-4 row now explicitly states both mocks return same OneDrive path; dedup -> 1 entry.
  - P7 (Doc cosmetic): v3-D4 updated: `$PROFILE` is conceptually (not technically) read-only per MS Learn.
- **Word count:** v3 ~830 words -> v4 ~1020 words (+190; within ~1100 target).
- **Vertical slice:** No new scope added. No new tests beyond GG-1..GG-7. No new options or architecture layers.
- **Files written:** `docs/plans/441-profile-path.md` (overwrite), `.squad/decisions/inbox/jiminy-441-v4-revision.md` (new).
- **History compressed:** S13-S16 entries compressed (14390B -> within gate). Post-append size: ~13900B.

### 441-v5-grill (jiminy-8, 2026-05-27)

- **Session:** 441-grill-v5
- **Task:** Final quality grill of plan #441 v5.1 (Donald revision) before implementation handoff.
- **Verdict:** REVISE (1 MEDIUM new finding).
- **Convergence:** All v4 HIGH/MEDIUM findings resolved (Donald F-1..F-5, Chip C-1/C-2, Pluto A-1). One LOW open (NF-3v4 Write-Skip).
- **New finding JN-1 [MEDIUM]:** H5 `$local:ps51Fallback`/`$local:ps7Fallback` inside `Write-PowerShellProfile` cannot be overridden from test scope. H3 "override `$ps51Fallback`/`$ps7Fallback` to temp paths" is inoperable -- PowerShell function-local bindings shadow calling-scope variables. GG-1/GG-4/GG-5 disk-writing tests will target REAL `$HOME` profile paths, not temp paths. Fix: parameterize `Write-PowerShellProfile` with optional fallback params (recommended Option A) or move fallback defs to file scope.
- **New finding JN-2 [LOW]:** NF-3v4 (Chip) still open -- `Write-Host` skip in v3-D4 should be `Write-Skip` for correct skip-counter.
- **Vertical slice:** CLEAN. 7 GG tests only. No scope creep across 6 revisions.
- **Files written:** `docs/plans/441-grill-jiminy-v5.md` (new), `.squad/decisions/inbox/jiminy-441-v5-grill.md` (new).
- **History size:** 8653B pre-append; no compression needed (gate = 14000B).

### 441-v5.2-verify (jiminy-9, 2026-05-27)

- **Session:** 441-grill-v5.2
- **Task:** Verify Mickey's v5.2 patch resolves JN-1 (function-local shadow bug) and JN-2 (Write-Host skip).
- **Verdict:** SHIP.
- **JN-1 [RESOLVED]:** `Write-PowerShellProfile` parameterized with `-Ps51Fallback`/`-Ps7Fallback`. Defaults match production lines 17-18 verbatim. No `$local:ps51Fallback`/`$local:ps7Fallback` in function body. GG-1/GG-4/GG-5 all invoke with explicit named temp-path params. v5.2-D1 states contract. All 6 JN-1 checklist items pass.
- **JN-2 [RESOLVED/PARTIAL]:** `Write-Warning '[SKIPPED] C-2: ...'` explicit in v3-D4; `[SKIPPED]` prefix present; D2 (no Pester) preserved. C-3 implied by prose but no explicit `Write-Warning '[SKIPPED] C-3: ...'` example -- LOW gap (NF-J4).
- **New findings:** NF-J3 [LOW] -- v5 H5 changelog entry lacks "superseded by v5.2/JN-1" note (cosmetic). NF-J4 [LOW] -- C-3 skip example missing from v3-D4 (implementer must infer from C-2 pattern).
- **Files written:** `docs/plans/441-grill-jiminy-v5.2.md` (new), `.squad/decisions/inbox/jiminy-441-v5.2-verify.md` (new).
- **History size:** ~10900B pre-append; no compression needed (gate = 14000B).

### 451-plan-landing-audit (jiminy-10, 2026-05-27)

- **Session:** 451-plan-landing-audit
- **Task:** Hygiene audit of #451 vertical slice plan commit on squad/451-pwsh-parity-gaps.
- **Verdict:** DIRTY (2 items + 1 MEDIUM recommendation).
- **Findings:** (1) Plan file at `.squad/decisions/451-vertical-slice.md` breaks `docs/plans/` convention from #441 precedent -- MEDIUM. (2) 3 stale squad/* branches (442-profile-path-impl, scribe-decision-merge x2). (3) 3 undrained inbox files predating #451.
- **Clean items:** Domain scope tests-only (Chip solo authority), branch from develop confirmed, tree clean, Conventional Commits + Co-authored-by trailer correct, develop in sync.
- **Lesson:** Plans go to `docs/plans/{N}-{slug}.md`. `.squad/decisions/*.md` is for permanent sprint archives only. Enforce in spawn prompts.
- **Files written:** `.squad/decisions/inbox/jiminy-451-grill.md` (new).

---

## 2026-05-27 -- #451 Re-Audit Round 2

- Round 1 path-move finding resolved: Chip moved plan correctly.
- Learned: check trailer blank-line separation -- concatenated trailers still parse but look sloppy.
- Scope creep detection works: caught tests-only -> tests+CI expansion. Flag for Coordinator, not block.
- Stale branches and inbox backlog: carry forward as non-blocking until Coordinator drains.

## 2026-05-27 -- #451 Quick Sweep Round 3

- **R3 Verdict:** DIRTY -- Chip's claimed v4 trailer fix missed: commit 461befc still has Co-authored-by concatenated to body (no blank line). Worktree clean, issue #461 filed, inbox drift minimal. Need v4 redo with blank line.

- **2026-05-27 R4 #451:** Double-blank-line bug (no BL before trailer) leaves git interpret-trailers --parse seeing concatenated text, not trailer -- requires commit rebuild (reset --soft, sequential commits preserve contents), old SHAs become unreachable, doc coordination + final hygiene gate closes loop.

## 2026-05-28 -- Hygiene Audit: Issue #451 Vertical Slice Plan (Rounds 1-4)

- **R1 verdict:** DIRTY (2 findings + 1 rec). Domain scope PASS (tests/**). Plan file location CONCERN (wrong canonical home). Worktree/Branch state PASS. Main checkout drift DIRTY (stale branches, undrained inbox).
- **R2 verdict:** CLEAN (caveats noted). Plan moved to docs/plans/ OK. Trailers CAVEAT (no blank line before Co-authored-by; git parses but violates conventional-commits).
- **R3 verdict:** DIRTY. Trailer format STILL BROKEN. Need v4 commit with blank line before trailer.
- **R4 verdict:** CLEAN (5-point checklist). Trailers verified (72b80bb, 18f170a). Old SHAs (461befc, b274cebe) orphaned. Worktree clean.
- **Key learning:** Trailer format is a hygiene gate; verify via git interpret-trailers --parse. Cosmetic issues in R2/R3 escalate if not corrected before R4 verification.

## 2026-05-30 -- #470 Plan v5 Fresh-Eyes Grill
- Verdict: REQUEST CHANGES. Blockers: CI/e2e wiring mismatch, incomplete public flag-combo/root tests, baseline fixture pre-change anchoring, and flag re-run idempotency test gap.
- 2026-05-30 #470 v6: REQUEST CHANGES -- Linux Fixture Provenance omits current prereqs/dotfiles/git-hook no-arg behavior; other v5 blockers verified fixed.
- 2026-05-30 #470 v7: PUSHED Fixture Provenance order fix -- Linux prereqs/tools/dotfiles/git-hook and Windows winget-check/tools/git-hook verified from setup scripts.
