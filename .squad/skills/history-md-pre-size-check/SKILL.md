---
name: "history-md-pre-size-check"
description: "Before appending to any agent history.md, check the file size and either shorten the entry or archive old entries if (current_size + planned_bytes) > 14336. Prevents mid-sprint Jiminy emergency compresses and post-batch audit blockers."
domain: "repo-meta, agent-hygiene"
confidence: "medium"
source: "earned (issues #398, Sprint 17 retro -- 3+ observations across 3 sprints)"
---

## Context

Every agent appends work records to `.squad/agents/{name}/history.md` after each task.
The repo enforces a hard gate of 15360 bytes (15 KB) on that file via the pre-commit hook.
Agents consistently skip a size check before appending, trusting that their entry is small.
It is not always small. Blindly appending and pushing then triggers one of two failure modes:

1. **Pre-commit block.** The commit fails; the agent's work is left uncommitted while
   the coordinator must intervene to compress the file before the sprint can continue.

2. **Post-batch audit blocker.** The oversized file lands on develop and is caught by
   Jiminy during the EOS audit. Jiminy compresses it in a follow-up PR, but this is
   wasted ceremony and delays the sprint close.

Both failure modes have occurred in three consecutive sprints (15, 16, 17). The fix
is a single size read before each append. This skill codifies that pre-check as a
mandatory step.

**Hard gate:** 15360 bytes (pre-commit hook in `hooks/pre-commit`, Check 4).
**Safe threshold:** 14336 bytes (90% of the gate, leaving ~1 KB headroom).

## Recipe

Run these steps IN ORDER every time you are about to append to your own
`.squad/agents/{name}/history.md`. Replace `{name}` with your agent name.

```powershell
# Step 1. Read current file size (bytes).
$histPath = ".squad/agents/{name}/history.md"
$size = (Get-Item $histPath).Length
Write-Host "INFO: history.md current size: $size bytes (gate: 15360)"

# Step 2. Estimate planned entry size.
# Rough rule: 1 KB = ~1000 characters of plain ASCII text.
# If your entry is a short 3-5 line bullet, budget ~200-400 bytes.
# If your entry is a full section with code blocks, budget ~800-2000 bytes.
$plannedBytes = <your estimate>

# Step 3. Decide path.
if (($size + $plannedBytes) -gt 14336) {
    # Option A: Shorten the entry.
    # Cut your planned entry to 1-2 lines:
    #   "Sprint NN -- #NNN: <one-sentence summary>. PR #NNN."
    # Prefer Option A if you have a prior section that is already a stub.

    # Option B: Mini-fold (archive old entries first).
    # Move entries from pre-Sprint-(current-2) or older to history-archive.md:
    #   1. Open history.md. Identify the oldest dated section(s).
    #   2. Cut those sections and paste them into history-archive.md.
    #   3. Save history-archive.md. Verify: (Get-Item ".squad/agents/{name}/history-archive.md").Length
    #   4. Save history.md with the old sections removed.
    #   5. Re-measure: $size = (Get-Item $histPath).Length
    #   6. Confirm ($size + $plannedBytes) -le 14336 before proceeding.
    Write-Warning "SIZE CHECK: $size + $plannedBytes = $($size + $plannedBytes) > 14336. Applying Option A or B."
}

# Step 4. Append the (possibly shortened) entry.
# ... your append logic here ...

# Step 5. Post-write verification.
$postSize = (Get-Item $histPath).Length
Write-Host "INFO: history.md post-write size: $postSize bytes"
if ($postSize -gt 15360) {
    Write-Error "GATE EXCEEDED: $postSize > 15360. Compress immediately before git add."
    # Do NOT proceed to git add until size is under the gate.
}
```

### Why this order

- **Size read before append** (Step 1) catches the problem before any bytes are
  written, giving you a clean recovery path (shorten the entry, never touch git).
- **Option A before Option B.** Shortening is always cheaper than a full archive fold.
  Archive only when Option A would produce a stub so terse it would be useless as a
  history record.
- **Post-write verify** (Step 5) is the safety net for mis-estimates. If you undercount
  your entry, the post-write check catches the overrun before `git add`.

### Bash / zsh equivalent (for agents running on Linux)

```bash
hist_path=".squad/agents/{name}/history.md"
size=$(wc -c < "$hist_path")
echo "INFO: history.md current size: $size bytes (gate: 15360)"
# Same decision logic as above; use wc -c for byte count (matches git blob size).
```

## Examples

**Sprint 15 -- pluto/history.md and scribe/history.md (first documented occurrence):**
Both files exceeded the gate during the Sprint 15 EOS sweep. Compressed during Ralph's
cleanup before the 0.9.5 release cut (commit 7fe4eb0, "chore(ralph): Sprint 15 EOS
cleanup -- 0.9.5 final state"). Root cause: no pre-check; appends accumulated across
the sprint.

**Sprint 16 -- pluto/history.md compressed 15694 B -> 8734 B (scribe-8, PR #378):**
Scribe ran an EOS cleanup pass and found pluto/history.md over the gate. Compressed
by moving pre-Sprint-13 entries to history-archive.md. Merge commit: df59a9c
("Merge pull request #378 from primetimetank21/squad/scribe-s16-eos-cleanup").

**Sprint 17 -- donald/history.md compressed 15860 B -> 10236 B (jiminy-5, PR #390):**
Donald-2 appended the #389 sprint-end-labels entry without a size check. File reached
15860 B, exceeding the 15360 B gate. Jiminy caught it in the post-batch audit and
compressed by moving pre-Sprint-12 entries to history-archive.md (6298 B moved).
Commit: 6375a49 ("chore(hygiene): Sprint 17 Wave 1 post-batch audit fixes (#390)").
Sprint 17 retro names this as the #1 "What surprised us" item and explicitly calls for
this SKILL.

**Lifecycle math from Sprint 17:**
- donald/history.md at overrun: 15860 B (500 B over gate)
- Jiminy compress delta: -5624 B (moved 2 sprint's worth of entries to archive)
- Post-compress: 10236 B (33% under gate, safe for 3-5 more sprints at typical velocity)

## Anti-Patterns

- **Blind append + git push without size check.** The #1 trigger for all three
  incidents above. The entry always feels small; the file is not always small.
- **Trusting "my entry is short."** A single entry with two code blocks and a
  methodology subsection can easily run 1500-2000 bytes. Always measure.
- **Compressing only after git push.** Once the oversized file is on develop,
  recovery requires a follow-up PR (Jiminy's compress commit), which is
  ceremony that costs coordinator time and sprint bandwidth.
- **Archiving inside the same append PR.** If you archive AND append in one
  commit, a bug in the archive step (wrong section boundary) can corrupt both
  history.md and history-archive.md simultaneously. Always: check, then optionally
  archive (separate save), then append, then post-verify.
- **Setting the threshold at exactly 15360.** The pre-commit hook fires at 15360.
  If your estimate is off by even 1 byte, the commit fails. Use 14336 (90%) as
  the threshold so there is always ~1 KB of headroom for measurement error.

## Related Skills

- `.squad/skills/history-compression/SKILL.md` -- the full compression recipe
  (multi-sprint heuristics, front-matter verbatim rule, 13 KB target). Use when
  Option B (mini-fold) above needs guidance on what to keep vs. archive.
- `.squad/skills/worktree-remove-first/SKILL.md` -- companion cleanup discipline;
  harvest hygiene files (including history.md appends) before removing the worktree.
- `.squad/skills/pre-spawn-checklist/SKILL.md` -- the mandatory hygiene tail for
  every spawn; references this skill for history.md append gate awareness.

## References

- Issue #398 -- formalization request (Sprint 18)
- Sprint 17 retro (`.squad/retros/2026-05-18-sprint-17-retro.md`) -- "What surprised
  us: history.md gate breeched mid-sprint (RECURRING)" and "Key learnings: Pre-append
  history.md size check missing"
- PR #390 (commit 6375a49) -- Sprint 17 incident: donald/history.md 15860->10236 B
- PR #378 (commit df59a9c / 8e2c659) -- Sprint 16 incident: pluto/history.md 15694->8734 B
- Commit 7fe4eb0 -- Sprint 15 EOS cleanup (pluto + scribe history compress)
- `hooks/pre-commit` Check 4 -- the 15360 B gate enforcement

**Last reviewed:** 2026-05-17 (Sprint 18, issue #398)
