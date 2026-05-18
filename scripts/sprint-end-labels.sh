#!/usr/bin/env bash
# scripts/sprint-end-labels.sh -- Sprint-end label automation (Issue #382)
#
# Owner: Donald
# Closes: #382
#
# Applies sprint-end label transitions to all issues and PRs carrying a given
# sprint label. For each match:
#   1. Remove release:backlog (if present)
#   2. Add release:shipped-X.Y.Z (if missing)
#
# Verification (HARD REQUIREMENT per Earl directive):
#   After every gh issue edit --add-label or --remove-label, re-query the
#   issue via `gh issue view <N> --json labels` and assert the desired state.
#   Retry up to 3 times with exponential backoff (1s, 2s, 4s).
#   Fail loudly if still mismatched after the final retry.
#
# Idempotent: safe to run twice. A second run finds no work to do.
#
# Type/area/squad/priority labels are NEVER touched by this script.
#
# Usage:
#   scripts/sprint-end-labels.sh \
#     --sprint sprint:17 \
#     --release-label release:shipped-1.17.0 \
#     [--repo owner/repo] \
#     [--dry-run]
#
# Examples:
#   # Dry-run (no writes):
#   scripts/sprint-end-labels.sh --sprint sprint:16 \
#     --release-label release:shipped-1.16.0 --dry-run
#
#   # Live run:
#   scripts/sprint-end-labels.sh --sprint sprint:17 \
#     --release-label release:shipped-1.17.0

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults / arg parsing
# ---------------------------------------------------------------------------

SPRINT_LABEL=""
RELEASE_LABEL=""
REPO=""
DRY_RUN=0
BACKLOG_LABEL="release:backlog"

usage() {
  sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sprint)
      SPRINT_LABEL="${2:-}"
      shift 2
      ;;
    --release-label)
      RELEASE_LABEL="${2:-}"
      shift 2
      ;;
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage
      ;;
  esac
done

if [[ -z "$SPRINT_LABEL" ]]; then
  echo "ERROR: --sprint <label> is required (e.g. --sprint sprint:17)" >&2
  exit 2
fi

if [[ -z "$RELEASE_LABEL" ]]; then
  echo "ERROR: --release-label <label> is required (e.g. --release-label release:shipped-1.17.0)" >&2
  exit 2
fi

case "$RELEASE_LABEL" in
  release:shipped-*) : ;;
  *)
    echo "ERROR: --release-label must start with 'release:shipped-' (got: $RELEASE_LABEL)" >&2
    exit 2
    ;;
esac

# ---------------------------------------------------------------------------
# Tool checks
# ---------------------------------------------------------------------------

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: gh CLI not found on PATH" >&2
  exit 127
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq not found on PATH" >&2
  exit 127
fi

GH_REPO_ARGS=()
if [[ -n "$REPO" ]]; then
  GH_REPO_ARGS=(--repo "$REPO")
fi

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------

log()  { printf '[sprint-end-labels] %s\n' "$*"; }
warn() { printf '[sprint-end-labels] WARN: %s\n' "$*" >&2; }
err()  { printf '[sprint-end-labels] ERROR: %s\n' "$*" >&2; }

# ---------------------------------------------------------------------------
# Core: verify label state for a single issue/PR number.
#
# Args: <number> <expected_label> <mode>
#   mode = "present" or "absent"
# Returns: 0 if labels match expectation, 1 otherwise.
# ---------------------------------------------------------------------------

has_label() {
  local number="$1"
  local target="$2"
  gh issue view "$number" "${GH_REPO_ARGS[@]}" --json labels \
    | jq -e --arg t "$target" '.labels | map(.name) | index($t) != null' \
    >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Verification loop with exponential backoff.
#
# Args: <number> <label> <mode>   (mode: "present" | "absent")
# Retries: up to 3 times, sleeping 1s, 2s, 4s between attempts.
# Exits the script (non-zero) on final failure.
# ---------------------------------------------------------------------------

verify_with_retry() {
  local number="$1"
  local label="$2"
  local mode="$3"
  local delays=(1 2 4)
  local attempt=0

  while :; do
    if [[ "$mode" == "present" ]]; then
      if has_label "$number" "$label"; then
        log "    verified: #$number has '$label'"
        return 0
      fi
    else
      if ! has_label "$number" "$label"; then
        log "    verified: #$number no longer has '$label'"
        return 0
      fi
    fi

    if (( attempt >= ${#delays[@]} )); then
      err "verification FAILED for #$number after $attempt retries"
      err "  expected: $label is $mode"
      err "  current labels: $(gh issue view "$number" "${GH_REPO_ARGS[@]}" --json labels --jq '[.labels[].name] | join(", ")')"
      exit 1
    fi

    local sleep_for="${delays[$attempt]}"
    warn "verification mismatch for #$number (expected '$label' $mode); retry in ${sleep_for}s"
    sleep "$sleep_for"
    attempt=$(( attempt + 1 ))
  done
}

# ---------------------------------------------------------------------------
# Apply label changes for a single issue/PR.
#
# Never touches type:, area:, squad:, priority: labels. Only release:* and
# only the two specific labels passed in (release:backlog and the shipped one).
# ---------------------------------------------------------------------------

process_issue() {
  local number="$1"
  local title="$2"
  local current_labels="$3"   # comma-joined string for log lines only

  log "issue #$number: $title"
  log "  current labels: $current_labels"

  local has_backlog="no"
  local has_shipped="no"
  if printf '%s' ",$current_labels," | grep -q ",${BACKLOG_LABEL},"; then
    has_backlog="yes"
  fi
  if printf '%s' ",$current_labels," | grep -q ",${RELEASE_LABEL},"; then
    has_shipped="yes"
  fi

  # --- step 1: remove release:backlog if present
  if [[ "$has_backlog" == "yes" ]]; then
    if (( DRY_RUN )); then
      log "  DRY-RUN would remove: $BACKLOG_LABEL"
    else
      log "  removing: $BACKLOG_LABEL"
      if ! gh issue edit "$number" "${GH_REPO_ARGS[@]}" --remove-label "$BACKLOG_LABEL" >/dev/null; then
        warn "  gh issue edit --remove-label returned non-zero (continuing into verify)"
      fi
      verify_with_retry "$number" "$BACKLOG_LABEL" "absent"
    fi
  else
    log "  skip remove: $BACKLOG_LABEL not present (idempotent)"
  fi

  # --- step 2: add release:shipped-X.Y.Z if missing
  if [[ "$has_shipped" == "no" ]]; then
    if (( DRY_RUN )); then
      log "  DRY-RUN would add: $RELEASE_LABEL"
    else
      log "  adding: $RELEASE_LABEL"
      if ! gh issue edit "$number" "${GH_REPO_ARGS[@]}" --add-label "$RELEASE_LABEL" >/dev/null; then
        warn "  gh issue edit --add-label returned non-zero (continuing into verify)"
      fi
      verify_with_retry "$number" "$RELEASE_LABEL" "present"
    fi
  else
    log "  skip add: $RELEASE_LABEL already present (idempotent)"
  fi
}

# ---------------------------------------------------------------------------
# Main: query issues + PRs carrying the sprint label, then process each.
# ---------------------------------------------------------------------------

main() {
  log "sprint label   : $SPRINT_LABEL"
  log "release label  : $RELEASE_LABEL"
  log "dry-run        : $([[ $DRY_RUN -eq 1 ]] && echo yes || echo no)"
  if [[ -n "$REPO" ]]; then
    log "repo           : $REPO"
  else
    log "repo           : (default from git remote)"
  fi

  # gh issue list treats PRs as issues only when querying via the search API.
  # We pull both via --search to capture issues AND PRs in one call.
  local search_query
  search_query="label:\"$SPRINT_LABEL\" state:closed"

  log "querying: $search_query (state:closed)"

  # Use --search so both issues and PRs are returned. Cap at 200; warn if hit.
  local json
  json=$(gh issue list \
    "${GH_REPO_ARGS[@]}" \
    --state closed \
    --search "label:\"$SPRINT_LABEL\"" \
    --json number,title,labels \
    --limit 200)

  local count
  count=$(printf '%s' "$json" | jq 'length')

  log "found $count issue(s)/PR(s) with label '$SPRINT_LABEL'"

  if [[ "$count" -eq 0 ]]; then
    log "nothing to do. exiting cleanly."
    return 0
  fi

  if [[ "$count" -ge 200 ]]; then
    warn "hit the 200-item cap; re-run with a narrower sprint label if more exist"
  fi

  # Iterate. Use process substitution to avoid subshell variable scoping.
  local total=0 changed=0 skipped=0
  while IFS=$'\t' read -r number title labels_csv; do
    total=$(( total + 1 ))
    local before="$labels_csv"
    process_issue "$number" "$title" "$labels_csv"

    # Tally: did this issue need any change?
    local needed_change=0
    if printf '%s' ",$before," | grep -q ",${BACKLOG_LABEL},"; then
      needed_change=1
    fi
    if ! printf '%s' ",$before," | grep -q ",${RELEASE_LABEL},"; then
      needed_change=1
    fi
    if (( needed_change )); then
      changed=$(( changed + 1 ))
    else
      skipped=$(( skipped + 1 ))
    fi
  done < <(printf '%s' "$json" \
    | jq -r '.[] | [(.number|tostring), .title, ([.labels[].name] | join(","))] | @tsv')

  log "summary: total=$total changed=$changed already-correct=$skipped dry-run=$([[ $DRY_RUN -eq 1 ]] && echo yes || echo no)"
}

main "$@"
