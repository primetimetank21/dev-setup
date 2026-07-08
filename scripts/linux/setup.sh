#!/usr/bin/env bash
# scripts/linux/setup.sh -- Core Linux/macOS/WSL installer (#468 flags-first)
#
# Called by: setup.sh (root entry point)
#
# Usage (direct):
#   bash scripts/linux/setup.sh [--list] [--help] [--only=a,b] [--skip=a,b]
#
# Flags:
#   --list          Print available tools (alphabetical), exit 0. No install.
#   --help          Print usage, exit 0.
#   --only=a,b,c    Install ONLY the listed tools (comma-separated).
#   --skip=a,b,c    Install all default tools EXCEPT the listed ones.
#   --only and --skip are mutually exclusive.
#
# Hidden test seam (not in --help):
#   --tools-dir=<path>   Override the tools directory (test use only).

set -euo pipefail
exec 2>&1  # Merge stderr into stdout for ordered output in piped/Devcontainer environments

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="${SCRIPT_DIR}/tools"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"

# ---------------------------------------------------------------------------
# DEFAULT_TOOLS -- single ordered source of truth for a no-arg default run.
# Adding a .sh file to tools/ makes it AvailableTools (selectable via --only)
# but does NOT add it here. Promotion to default requires editing this array.
# ---------------------------------------------------------------------------
DEFAULT_TOOLS=(
  "prereqs"
  "zsh"
  "uv"
  "nvm"
  "gh"
  "auth"
  "copilot-cli"
  "squad-cli"
  "dotfiles"
  "git-hook"
)

# ---------------------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------------------
ARG_ONLY=""
ARG_SKIP=""
ARG_LIST=0
ARG_HELP=0
ARG_TOOLS_DIR=""  # hidden test seam

for arg in "$@"; do
  case "$arg" in
    --only=*)   ARG_ONLY="${arg#--only=}" ;;
    --skip=*)   ARG_SKIP="${arg#--skip=}" ;;
    --list)     ARG_LIST=1 ;;
    --help)     ARG_HELP=1 ;;
    --tools-dir=*) ARG_TOOLS_DIR="${arg#--tools-dir=}" ;;
    *)
      log_error "Unknown argument: $arg"
      log_error "Run with --help for usage."
      exit 1
      ;;
  esac
done

# Override TOOLS_DIR from test seam if provided
if [[ -n "$ARG_TOOLS_DIR" ]]; then
  TOOLS_DIR="$ARG_TOOLS_DIR"
  # Load DEFAULT_TOOLS from defaults.txt in the stub dir (test self-contained)
  if [[ -f "${TOOLS_DIR}/defaults.txt" ]]; then
    mapfile -t DEFAULT_TOOLS < "${TOOLS_DIR}/defaults.txt"
  fi
fi

# ---------------------------------------------------------------------------
# Dispatcher
# ---------------------------------------------------------------------------
run_tool() {
  local tool_name="$1"
  local tool_script="${TOOLS_DIR}/${tool_name}.sh"

  if [[ ! -f "$tool_script" ]]; then
    log_warn "Tool script not found, skipping: ${tool_script}"
    return 0
  fi

  log_info "Installing: ${tool_name}"
  # shellcheck source=/dev/null
  if bash "${tool_script}"; then
    log_ok "${tool_name} -- done"
  else
    log_error "${tool_name} -- FAILED (see above)"
    return 1
  fi
}

# Build AvailableTools: basenames of all *.sh in TOOLS_DIR
get_available_tools() {
  local tool
  for tool in "${TOOLS_DIR}"/*.sh; do
    [[ -f "$tool" ]] && basename "$tool" .sh
  done | sort
}

# Validate a CSV list: no blanks, no empty tokens, each name in AvailableTools
validate_csv_shape() {
  local input="$1"
  if [[ -z "$input" ]]; then
    log_error "Flag requires at least one tool name."
    exit 1
  fi
  if [[ "$input" == *,,* || "$input" == ,* || "$input" == *, ]]; then
    log_error "Empty tool name in list (check commas)."
    exit 1
  fi
}

print_help() {
  cat <<'USAGE'
Usage: setup.sh [OPTIONS]

Install developer tools on Linux/macOS/WSL.

Options:
  --list            Print available tools (alphabetical order), exit 0.
  --help            Print this help message, exit 0.
  --only=a,b,c      Install ONLY the listed tools (comma-separated).
  --skip=a,b,c      Install all default tools EXCEPT the listed ones.

Notes:
  --only and --skip are mutually exclusive.
  Unknown tool names exit with an error and print the available tool list.
  A no-arg run installs all default tools in the defined order.
USAGE
}

# ---------------------------------------------------------------------------
# --help / --list handling (exit before any install logic)
# ---------------------------------------------------------------------------
if [[ $ARG_HELP -eq 1 ]]; then
  print_help
  exit 0
fi

if [[ $ARG_LIST -eq 1 ]]; then
  get_available_tools
  exit 0
fi

# ---------------------------------------------------------------------------
# Mutual exclusion
# ---------------------------------------------------------------------------
if [[ -n "$ARG_ONLY" && -n "$ARG_SKIP" ]]; then
  log_error "--only and --skip are mutually exclusive."
  exit 1
fi

# ---------------------------------------------------------------------------
# Build FinalToolSet
# ---------------------------------------------------------------------------
build_final_toolset() {
  local -n result_ref=$1

  if [[ -n "$ARG_ONLY" ]]; then
    validate_csv_shape "$ARG_ONLY"
    IFS=',' read -ra only_list <<< "$ARG_ONLY"
    # Validate each name against AvailableTools
    local available
    mapfile -t available < <(get_available_tools)
    for name in "${only_list[@]}"; do
      local found=0
      for avail in "${available[@]}"; do
        [[ "$avail" == "$name" ]] && found=1 && break
      done
      if [[ $found -eq 0 ]]; then
        log_error "Unknown tool: ${name}"
        log_error "Available tools: $(get_available_tools | tr '\n' ' ')"
        exit 1
      fi
    done
    result_ref=("${only_list[@]}")

  elif [[ -n "$ARG_SKIP" ]]; then
    validate_csv_shape "$ARG_SKIP"
    IFS=',' read -ra skip_list <<< "$ARG_SKIP"
    # Validate each skip name against AvailableTools
    local available
    mapfile -t available < <(get_available_tools)
    for name in "${skip_list[@]}"; do
      local found=0
      for avail in "${available[@]}"; do
        [[ "$avail" == "$name" ]] && found=1 && break
      done
      if [[ $found -eq 0 ]]; then
        log_error "Unknown tool: ${name}"
        log_error "Available tools: $(get_available_tools | tr '\n' ' ')"
        exit 1
      fi
    done
    # Filter DEFAULT_TOOLS, preserving order
    for tool in "${DEFAULT_TOOLS[@]}"; do
      local skip=0
      for s in "${skip_list[@]}"; do
        [[ "$s" == "$tool" ]] && skip=1 && break
      done
      [[ $skip -eq 0 ]] && result_ref+=("$tool")
    done

  else
    result_ref=("${DEFAULT_TOOLS[@]}")
  fi
}

# ---------------------------------------------------------------------------
# Platform detection (kept for logging; prereqs.sh re-detects internally)
# ---------------------------------------------------------------------------
detect_platform() {
  local os
  os="$(uname -s)"
  if [[ "$os" == "Darwin" ]]; then
    echo "macos"
  elif grep -qi microsoft /proc/version 2>/dev/null; then
    echo "wsl"
  else
    echo "linux"
  fi
}

# ---------------------------------------------------------------------------
# Main dispatch
# ---------------------------------------------------------------------------
main() {
  local platform
  platform="$(detect_platform)"

  log_info "Starting Linux/macOS setup"
  log_info "Platform: ${platform}"
  log_info "Repo root: ${REPO_ROOT}"

  local -a final_tools=()
  build_final_toolset final_tools

  for tool in "${final_tools[@]}"; do
    run_tool "$tool"
  done

  log_ok "Setup complete. Open a new shell to apply all changes."
}

main

