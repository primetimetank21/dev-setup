---
name: gh-label-verify-retry
confidence: medium
applications: 1
last_updated: 2026-05-17
---

# gh-label-verify-retry

## When to use

Any time a script or workflow calls `gh issue edit --add-label` or
`gh issue edit --remove-label` (or the equivalent for PRs) and needs to be
**certain** the label state actually changed before continuing. The CLI's
exit code is necessary but not sufficient: GitHub's labels are eventually
consistent in rare cases, and a 0 exit does not always mean "label is now
applied as of the next read."

## The rule

Treat every label mutation as a write-then-verify pair:

1. Call `gh issue edit <N> --add-label X` (or `--remove-label X`).
2. Re-query: `gh issue view <N> --json labels`.
3. Assert the expected state (`X` present after add, absent after remove).
4. If the assertion fails, retry the **verification read** (not the write)
   on an exponential backoff: 1s, 2s, 4s, then bail.
5. If still mismatched after the third retry, fail loudly with the actual
   current label set in the error message.

Do not retry the write. The CLI returned 0; re-writing risks creating
duplicates in audit trails. Only retry the read.

## Why retry instead of trust

- GitHub returns 200 OK on the label PATCH even when the label set takes
  a tick to propagate to the issue's REST representation.
- A flaky network can drop the response after the server has committed.
- Most importantly: in batch automation (sprint-end transitions across N
  issues) a silent miss compounds into a triage mess on Monday morning.

## Backoff numbers

1s, 2s, 4s -- total worst-case wait 7s per failed verification. Cheap
enough to apply on every label op. If your script does 30 transitions and
half need one retry, that is ~15s of extra wall time and zero silent
failures.

## Implementation sketch (bash)

```bash
has_label() {
  gh issue view "$1" --json labels \
    | jq -e --arg t "$2" '.labels | map(.name) | index($t) != null' \
    >/dev/null
}

verify_with_retry() {
  local number="$1" label="$2" mode="$3"   # mode: present|absent
  local delays=(1 2 4) attempt=0
  while :; do
    if [[ "$mode" == "present" ]] && has_label "$number" "$label"; then return 0; fi
    if [[ "$mode" == "absent" ]]  && ! has_label "$number" "$label"; then return 0; fi
    if (( attempt >= ${#delays[@]} )); then
      echo "ERROR: label state never matched after 3 retries" >&2
      exit 1
    fi
    sleep "${delays[$attempt]}"
    attempt=$((attempt + 1))
  done
}
```

## Anti-patterns

- **Trust exit 0 alone.** It tells you the API accepted the request, not
  that the next reader will see the result.
- **Retry the write.** Creates audit noise and can re-apply the wrong
  state if a race occurred.
- **Infinite retry.** A stuck label state is a bug, not a transient. Bail
  loudly after 3 tries so a human can investigate.
- **Swallow the final error.** The error message must include the current
  label list so the operator can see what *did* land.

## Applications

1. **PR #N (Sprint 16 sprint-end-labels)** -- Donald applied this pattern
   in `scripts/sprint-end-labels.sh` (`verify_with_retry`) and tested via
   `tests/test_sprint_end_labels.ps1` with a function-override harness.
   The harness asserts both the success-on-third-call and
   fail-loudly-after-3 paths.

## Validation

Run the test suite:

```powershell
pwsh -File tests\test_sprint_end_labels.ps1
```

Two of the tests exercise the retry loop directly (one happy-path, one
fail-loudly path) by overriding `has_label` in a sourced helpers shim.
