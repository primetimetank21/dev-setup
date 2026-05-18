#!/usr/bin/env bash
# scripts/squad-spawn.sh
# Assembles a coordinator spawn prompt by appending the hygiene tail template.
#
# Usage:
#   bash scripts/squad-spawn.sh [--body <path>] [--template <path>] \
#       --name <agent> --issue <N> --worktree <path>
#   cat body.md | bash scripts/squad-spawn.sh --name donald --issue 123 \
#       --worktree /path/to/dev-setup-123
#
# Options:
#   --body <path>      Spawn-prompt body file (default: stdin)
#   --template <path>  Hygiene tail template
#                      (default: .squad/templates/spawn-prompt-hygiene.md)
#   --name <agent>     Agent name -- replaces {name} in template
#   --issue <N>        Issue number -- replaces {N} in template
#   --worktree <path>  Worktree path -- replaces {worktree-path} in template
#
# Output: assembled prompt on stdout.
# Exit 0 on success, exit 1 on error.
# Idempotent: if the body already contains all 6 hygiene tail markers the
# template is not appended again.

set -euo pipefail

body_path=''
template_path=''
agent_name=''
issue_num=''
worktree_path=''

while [ $# -gt 0 ]; do
    case "$1" in
        --body)     body_path="$2";     shift 2 ;;
        --template) template_path="$2"; shift 2 ;;
        --name)     agent_name="$2";    shift 2 ;;
        --issue)    issue_num="$2";     shift 2 ;;
        --worktree) worktree_path="$2"; shift 2 ;;
        *)
            echo "ERROR: Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

# Resolve template path (default: .squad/templates/spawn-prompt-hygiene.md at repo root)
script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(dirname "$script_dir")"
if [ -z "$template_path" ]; then
    template_path="${repo_root}/.squad/templates/spawn-prompt-hygiene.md"
fi

if [ ! -f "$template_path" ]; then
    echo "ERROR: Template not found: $template_path" >&2
    exit 1
fi

# Read body
if [ -n "$body_path" ]; then
    if [ ! -f "$body_path" ]; then
        echo "ERROR: Body file not found: $body_path" >&2
        exit 1
    fi
    body_text="$(cat "$body_path")"
else
    body_text="$(cat)"
fi

if [ -z "$(printf '%s' "$body_text" | tr -d '[:space:]')" ]; then
    echo "ERROR: Body is empty. Provide --body <path> or pipe body text via stdin." >&2
    exit 1
fi

# Read template and perform substitutions
template_text="$(cat "$template_path")"
if [ -n "$agent_name" ];    then template_text="${template_text//\{name\}/$agent_name}";         fi
if [ -n "$issue_num" ];     then template_text="${template_text//\{N\}/$issue_num}";             fi
if [ -n "$worktree_path" ]; then template_text="${template_text//\{worktree-path\}/$worktree_path}"; fi

# Idempotency: skip re-append if all 6 hygiene tail markers are already present
markers=(
    'CWD-pin'
    'base=develop discipline'
    'ASCII discipline'
    'history.md pre-size-check'
    'Worktree-remove-FIRST'
    'Hygiene tail completion'
)
all_present=true
for marker in "${markers[@]}"; do
    if ! printf '%s' "$body_text" | grep -qF "$marker"; then
        all_present=false
        break
    fi
done

if [ "$all_present" = true ]; then
    printf '%s' "$body_text"
else
    printf '%s\n\n---\n\n%s' "$body_text" "$template_text"
fi
