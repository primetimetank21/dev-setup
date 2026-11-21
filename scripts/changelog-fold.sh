#!/usr/bin/env bash
# scripts/changelog-fold.sh -- CHANGELOG fold automation (Issue #415)
#
# Usage:
#   bash scripts/changelog-fold.sh \
#     --release-version X.Y.Z \
#     --last-tag X.Y.W \
#     [--release-date YYYY-MM-DD]   (default: today)
#     [--changelog-path PATH]       (default: ./CHANGELOG.md)
#     [--dry-run]                   (default)
#     [--apply]

set -euo pipefail

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------

log()  { printf '[changelog-fold] %s\n'        "$*" >&2; }
warn() { printf '[changelog-fold] WARN: %s\n'  "$*" >&2; }
die()  { printf '[changelog-fold] ERROR: %s\n' "$*" >&2; exit 1; }
usage_die() { printf '[changelog-fold] ERROR: %s\n' "$*" >&2; exit 2; }

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

RELEASE_VERSION=""
LAST_TAG=""
RELEASE_DATE=""
CHANGELOG_PATH="./CHANGELOG.md"
MODE="dry-run"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release-version) RELEASE_VERSION="$2"; shift 2 ;;
    --last-tag)        LAST_TAG="$2";        shift 2 ;;
    --release-date)    RELEASE_DATE="$2";    shift 2 ;;
    --changelog-path)  CHANGELOG_PATH="$2";  shift 2 ;;
    --dry-run)         MODE="dry-run";       shift   ;;
    --apply)           MODE="apply";         shift   ;;
    *) usage_die "unknown argument: $1" ;;
  esac
done

[[ -n "$RELEASE_VERSION" ]] || usage_die "--release-version is required"
[[ -f "$CHANGELOG_PATH"  ]] || die "CHANGELOG not found: $CHANGELOG_PATH"

# Default release date to today
if [[ -z "$RELEASE_DATE" ]]; then
  RELEASE_DATE=$(date +%Y-%m-%d)
fi

# ---------------------------------------------------------------------------
# Idempotency gate
# ---------------------------------------------------------------------------

if grep -q "\[${RELEASE_VERSION}\]" "$CHANGELOG_PATH"; then
  die "version [${RELEASE_VERSION}] is already present in ${CHANGELOG_PATH} -- already folded (idempotency gate)"
fi

# ---------------------------------------------------------------------------
# Resolve last-tag commit date
# ---------------------------------------------------------------------------

LAST_TAG_DATE=""

if [[ -n "$LAST_TAG" ]]; then
  log "resolving tag SHA for: $LAST_TAG ..."
  LAST_TAG_SHA=$(git log -1 --format="%H" "$LAST_TAG" 2>/dev/null || true)
  if [[ -z "$LAST_TAG_SHA" ]]; then
    die "could not resolve tag: $LAST_TAG"
  fi
  log "last tag SHA : $LAST_TAG_SHA"
  LAST_TAG_DATE=$(git log -1 --format="%as" "$LAST_TAG")
  log "last tag date: $LAST_TAG_DATE"
else
  LAST_TAG_DATE=$(date -d "90 days ago" +%Y-%m-%d 2>/dev/null \
    || date -v -90d +%Y-%m-%d 2>/dev/null \
    || date +%Y-%m-%d)
  log "no --last-tag supplied; using $LAST_TAG_DATE as cutoff"
fi

# ---------------------------------------------------------------------------
# Enumerate merged PRs since last tag date
# ---------------------------------------------------------------------------

log "enumerating PRs merged since $LAST_TAG_DATE ..."
prs_json=$(gh pr list \
  --state merged \
  --search "merged:>=${LAST_TAG_DATE}" \
  --json number,title,labels,mergedAt \
  --limit 200 | tr -d '\r')
pr_count=$(printf '%s' "$prs_json" | jq 'length')
log "found $pr_count merged PR(s)"

# ---------------------------------------------------------------------------
# Enumerate closed issues since last tag date (excluding PR numbers)
# ---------------------------------------------------------------------------

log "enumerating issues closed since $LAST_TAG_DATE ..."
issues_json=$(gh issue list \
  --state closed \
  --search "closed:>=${LAST_TAG_DATE}" \
  --json number,title,labels,closedAt \
  --limit 200 | tr -d '\r')

# Filter: exclude items whose numbers appear in the PR list.
pr_numbers_arr=$(printf '%s' "$prs_json" | jq '[.[].number]')
issues_filtered=$(printf '%s' "$issues_json" | jq \
  --argjson prnums "$pr_numbers_arr" \
  '[.[] | select(.number as $n | ($prnums | index($n)) == null)]')
issue_count=$(printf '%s' "$issues_filtered" | jq 'length')
log "found $issue_count closed issue(s) (after PR dedup)"

# Combine and sort once; use stdin piping to avoid --argjson arg-length limits
combined_json=$(printf '%s\n%s' "$prs_json" "$issues_filtered" | jq -s 'add | sort_by(.number)')

# ---------------------------------------------------------------------------
# Categorize: label-first, then title-prefix, then Changed with WARN
# ---------------------------------------------------------------------------

categorize() {
  local number="$1" title="$2" labels_csv="$3"

  # Label takes priority
  case ",$labels_csv," in
    *",type:feature,"*) echo "Added";   return ;;
    *",type:bug,"*)     echo "Fixed";   return ;;
    *",type:chore,"*)   echo "Changed"; return ;;
    *",type:docs,"*)    echo "Changed"; return ;;
  esac

  # Fall back to title prefix (conventional commits)
  case "$title" in
    feat:*|"feat("*)                                    echo "Added";   return ;;
    fix:*|"fix("*)                                      echo "Fixed";   return ;;
    chore:*|"chore("*|docs:*|"docs("*|\
    refactor:*|"refactor("*|perf:*|"perf("*)           echo "Changed"; return ;;
  esac

  warn "#${number} '${title}': no label/prefix match -- categorized as Changed"
  echo "Changed"
}

# ---------------------------------------------------------------------------
# Build categorized entry lines
# ---------------------------------------------------------------------------

added_lines=""
changed_lines=""
fixed_lines=""
removed_lines=""

while IFS=$'\t' read -r number title labels_csv; do
  category=$(categorize "$number" "$title" "$labels_csv")
  entry="- ${title} (#${number})"
  case "$category" in
    Added)   added_lines="${added_lines}${entry}"$'\n' ;;
    Changed) changed_lines="${changed_lines}${entry}"$'\n' ;;
    Fixed)   fixed_lines="${fixed_lines}${entry}"$'\n' ;;
    Removed) removed_lines="${removed_lines}${entry}"$'\n' ;;
  esac
done < <(printf '%s' "$combined_json" | jq -r \
  '.[] | [(.number|tostring), .title, ([.labels // [] | .[].name] | join(","))] | @tsv' \
  | tr -d '\r')

# ---------------------------------------------------------------------------
# Check for missing entries in [Unreleased] -- warn to stderr
# ---------------------------------------------------------------------------

unreleased_content=$(awk '
  /^## \[Unreleased\]/ { found=1; next }
  found && /^## \[/    { exit }
  found                { print }
' "$CHANGELOG_PATH")

missing_list=""
while IFS=$'\t' read -r number _title; do
  if ! printf '%s' "$unreleased_content" | grep -q "(#${number})"; then
    if [[ -n "$missing_list" ]]; then missing_list="${missing_list}, "; fi
    missing_list="${missing_list}#${number}"
  fi
done < <(printf '%s' "$combined_json" | jq -r \
  '.[] | [(.number|tostring), .title] | @tsv' \
  | tr -d '\r')

if [[ -n "$missing_list" ]]; then
  warn "Missing from [Unreleased]: $missing_list"
fi

# ---------------------------------------------------------------------------
# Build the new [X.Y.Z] section
# ---------------------------------------------------------------------------

build_section() {
  printf '## [%s] - %s\n\n' "$RELEASE_VERSION" "$RELEASE_DATE"
  printf '### Added\n'
  printf '%s' "$added_lines"
  printf '\n'
  printf '### Changed\n'
  printf '%s' "$changed_lines"
  printf '\n'
  printf '### Fixed\n'
  printf '%s' "$fixed_lines"
  printf '\n'
  printf '### Removed\n'
  printf '%s' "$removed_lines"
}

NEW_SECTION=$(build_section)

# ---------------------------------------------------------------------------
# Summary / dry-run output
# ---------------------------------------------------------------------------

added_count=$(printf '%s' "$added_lines"   | grep -c '^-' || true)
changed_count=$(printf '%s' "$changed_lines" | grep -c '^-' || true)
fixed_count=$(printf '%s' "$fixed_lines"   | grep -c '^-' || true)
removed_count=$(printf '%s' "$removed_lines" | grep -c '^-' || true)

log "mode        : $MODE"
log "version     : $RELEASE_VERSION"
log "date        : $RELEASE_DATE"
log "last tag    : ${LAST_TAG:-<none>} (${LAST_TAG_DATE:-<unknown>})"
log "entries     : Added=${added_count} Changed=${changed_count} Fixed=${fixed_count} Removed=${removed_count}"

if [[ "$MODE" == "dry-run" ]]; then
  printf '\n=== Proposed [%s] section (dry-run) ===\n' "$RELEASE_VERSION"
  printf '%s\n' "$NEW_SECTION"
  printf '=== End proposed section ===\n'
  exit 0
fi

# ---------------------------------------------------------------------------
# Apply mode: splice new section into CHANGELOG.md
# ---------------------------------------------------------------------------

# Find the line number of ## [Unreleased]
unreleased_line=$(grep -n '^## \[Unreleased\]' "$CHANGELOG_PATH" | head -1 | cut -d: -f1)
if [[ -z "$unreleased_line" ]]; then
  die "could not find '## [Unreleased]' in $CHANGELOG_PATH"
fi

# Find the next version line after [Unreleased]
next_version_line=$(awk -v start="$unreleased_line" '
  NR > start && /^## \[/ { print NR; exit }
' "$CHANGELOG_PATH")

if [[ -z "$next_version_line" ]]; then
  die "could not find any existing version section after [Unreleased] in $CHANGELOG_PATH"
fi

# Build fresh [Unreleased] block
fresh_unreleased="## [Unreleased]"$'\n'$'\n'

# Assemble the new file
{
  head -n $(( unreleased_line - 1 )) "$CHANGELOG_PATH"
  printf '%s\n' "$fresh_unreleased"
  printf '%s\n\n' "$NEW_SECTION"
  tail -n +"${next_version_line}" "$CHANGELOG_PATH"
} > "${CHANGELOG_PATH}.tmp"

mv "${CHANGELOG_PATH}.tmp" "$CHANGELOG_PATH"

log "applied [${RELEASE_VERSION}] section to ${CHANGELOG_PATH}"
