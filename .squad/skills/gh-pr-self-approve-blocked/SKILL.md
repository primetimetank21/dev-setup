# Skill: GitHub Self-Approve Blocked on Copilot-Authored PRs

**Confidence:** medium (observed once, 2026-05-27 PR #458)
**Owner:** Chip (Tester)
**Issue:** Discovered during PR #458 review

---

## What

GitHub blocks `gh pr review <N> --approve` when the reviewer identity (Copilot bot)
is the same as the PR author. The GraphQL error is:

```
failed to create review: GraphQL: Review Can not approve your own pull request (addPullRequestReview)
```

This affects all squad agent PRs where Copilot is both author and reviewer.

---

## Pattern

### Detection

You will see this error if you try:

```powershell
gh pr review 458 --approve --body "..."
```

And the PR was created by the same GitHub account (e.g., the Copilot coding-agent bot).

### Recovery

Use `--comment` instead of `--approve`:

```powershell
gh pr review 458 --comment --body "## Verdict: APPROVED (comment -- self-approve blocked)
..."
```

Include a prominent `### Verdict: APPROVED` header in the comment body so the
intent is unambiguous in the PR thread. Earl or a human reviewer must click
Approve in the GitHub UI before merge.

---

## Routing

When posting a comment-only review (self-approve blocked):

1. Post the full review body as a `--comment` (not `--approve`)
2. Note in the review body: "GitHub blocked --approve (self-approve on Copilot-authored PR). Earl or a human reviewer must click Approve in the GitHub UI before merge."
3. Write the approval verdict to `.squad/decisions/inbox/{agent}-pr{N}-review.md` with the routing note
4. Log the block in agent history.md under "Learnings"

---

## Why This Matters

Squad agents both author and review PRs. The GitHub "can not approve your own
pull request" rule fires on the Copilot bot identity even across separate agent
spawns -- the bot identity is the same GitHub account regardless of which agent
is acting. Human approval is still required for merge.

---

## References

- PR #458 (first observed instance)
- Chip history.md entry 2026-05-27
