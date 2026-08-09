#!/usr/bin/env bash
# scripts/linux/setup.sh -- Core Linux/macOS/WSL installer (#468 flags-first)
#
# Called by: setup.sh (root entry point)
#
# Usage (direct):
#   bash scripts/linux/setup.sh [--list] [--help] [--only=a,b] [--skip=a,b]
#                                  [--interactive | --non-interactive]
#
# Flags:
#   --list          Print available tools (alphabetical), exit 0. No install.
#   --help          Print usage, exit 0.
#   --only=a,b,c    Install ONLY the listed tools (comma-separated).
#   --skip=a,b,c    Install all default tools EXCEPT the listed ones.
#   --interactive   Show the tool picker when a TTY is available.
#   --non-interactive
#                   Never show the tool picker.
#   --only and --skip are mutually exclusive.
#
# Hidden test seam (not in --help):
#   --tools-dir=<path>   Override the tools directory (test use only).
#   --selection-file=<path>
#                         Read selected tools from a file (test use only).

set -euo pipefail
exec 2>&1  # Merge stderr into stdout for ordered output in piped/Devcontainer environments

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="${SCRIPT_DIR}/tools"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/lib/tui.sh"

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
ARG_SELECTION_FILE=""  # hidden test seam
ARG_ONLY_SET=0    # tracks whether --only was explicitly provided
ARG_SKIP_SET=0    # tracks whether --skip was explicitly provided
ARG_INTERACTIVE_SET=0
ARG_NON_INTERACTIVE_SET=0
ARG_SELECTION_FILE_SET=0

for arg in "$@"; do
  case "$arg" in
    --only=*)   ARG_ONLY="${arg#--only=}"; ARG_ONLY_SET=1 ;;
    --skip=*)   ARG_SKIP="${arg#--skip=}"; ARG_SKIP_SET=1 ;;
    --list)     ARG_LIST=1 ;;
    --help)     ARG_HELP=1 ;;
    --interactive) ARG_INTERACTIVE_SET=1 ;;
    --non-interactive) ARG_NON_INTERACTIVE_SET=1 ;;
    --tools-dir=*) ARG_TOOLS_DIR="${arg#--tools-dir=}" ;;
    --selection-file=*)
      ARG_SELECTION_FILE="${arg#--selection-file=}"
      ARG_SELECTION_FILE_SET=1
      ;;
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
  # Use while-read instead of mapfile -- bash 3.2 (macOS) does not have mapfile
  if [[ -f "${TOOLS_DIR}/defaults.txt" ]]; then
    DEFAULT_TOOLS=()
    while IFS= read -r _line; do
      [[ -n "$_line" ]] && DEFAULT_TOOLS+=("$_line")
    done < "${TOOLS_DIR}/defaults.txt"
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
  --interactive     Show the tool picker when a TTY is available.
  --non-interactive Never show the tool picker.

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
if [[ $ARG_ONLY_SET -eq 1 && $ARG_SKIP_SET -eq 1 ]]; then
  log_error "--only and --skip are mutually exclusive."
  exit 1
fi

if [[ $ARG_INTERACTIVE_SET -eq 1 && $ARG_NON_INTERACTIVE_SET -eq 1 ]]; then
  log_error "--interactive and --non-interactive are mutually exclusive."
  exit 1
fi

if [[ $ARG_NON_INTERACTIVE_SET -eq 1 && $ARG_SELECTION_FILE_SET -eq 1 ]]; then
  log_error "--non-interactive and --selection-file are mutually exclusive."
  exit 1
fi

# (Note: ARG_ONLY_SET / ARG_SKIP_SET handle empty-value sentinels; build_final_toolset validates.)

# ---------------------------------------------------------------------------
# Interactive guard. Returns 0 (true) when the menu should run.
# ---------------------------------------------------------------------------
is_interactive() {
  if [[ $ARG_NON_INTERACTIVE_SET -eq 1 || $ARG_ONLY_SET -eq 1 || $ARG_SKIP_SET -eq 1 ]]; then
    return 1
  fi
  # --interactive + --selection-file: bypass CI/TTY detection so CI can test the menu path.
  if [[ $ARG_INTERACTIVE_SET -eq 1 && $ARG_SELECTION_FILE_SET -eq 1 ]]; then
    return 0
  fi
  if [[ "${SETUP_NON_INTERACTIVE:-}" == "1" || -n "${CI:-}" || -n "${GITHUB_ACTIONS:-}" ]]; then
    return 1
  fi
  if [[ ! -t 0 || ! -t 1 ]]; then
    return 1
  fi
  return 0
}


# ---------------------------------------------------------------------------
# Build FinalToolSet -- populates global FINAL_TOOLS (bash 3.2 safe: no
# local -n namerefs, no mapfile; use plain global array + while-read).
# ---------------------------------------------------------------------------
FINAL_TOOLS=()
build_final_toolset() {
  FINAL_TOOLS=()

  if [[ $ARG_SELECTION_FILE_SET -eq 1 && $ARG_ONLY_SET -eq 0 && $ARG_SKIP_SET -eq 0 ]]; then
    if [[ -z "$ARG_SELECTION_FILE" || ! -f "$ARG_SELECTION_FILE" ]]; then
      log_error "Selection file not found: ${ARG_SELECTION_FILE}"
      exit 1
    fi
    local _selection
    while IFS= read -r _selection || [[ -n "$_selection" ]]; do
      _selection="${_selection%$'\r'}"
      [[ -z "$_selection" ]] && continue
      if [[ -n "$ARG_ONLY" ]]; then
        ARG_ONLY="${ARG_ONLY},${_selection}"
      else
        ARG_ONLY="$_selection"
      fi
    done < "$ARG_SELECTION_FILE"
    ARG_ONLY_SET=1
  fi

  # Build available-tools list into a local array (while-read, not mapfile)
  local available=()
  local _t
  while IFS= read -r _t; do
    [[ -n "$_t" ]] && available+=("$_t")
  done < <(get_available_tools)

  if [[ $ARG_ONLY_SET -eq 1 ]]; then
    validate_csv_shape "$ARG_ONLY"
    local only_list=()
    IFS=',' read -ra only_list <<< "$ARG_ONLY"
    # Validate each name against AvailableTools
    local name avail found
    for name in "${only_list[@]}"; do
      found=0
      for avail in "${available[@]}"; do
        [[ "$avail" == "$name" ]] && found=1 && break
      done
      if [[ $found -eq 0 ]]; then
        log_error "Unknown tool: ${name}"
        log_error "Available tools: $(get_available_tools | tr '\n' ' ')"
        log_error "Use --list to see all available tools."
        exit 1
      fi
    done
    # ORDER PRESERVATION: iterate DEFAULT_TOOLS, include those requested.
    # Do NOT use input order -- dependencies require the default sequence.
    local tool _in_only
    for tool in "${DEFAULT_TOOLS[@]}"; do
      _in_only=0
      for name in "${only_list[@]}"; do
        [[ "$name" == "$tool" ]] && _in_only=1 && break
      done
      [[ $_in_only -eq 1 ]] && FINAL_TOOLS+=("$tool")
    done
    # Opt-in tools (requested but NOT in DEFAULT_TOOLS): append alphabetically.
    # These have no defined default position, so alphabetical is deterministic.
    local _in_default
    local _optin_names
    _optin_names=()
    for name in "${only_list[@]}"; do
      _in_default=0
      for tool in "${DEFAULT_TOOLS[@]}"; do
        [[ "$tool" == "$name" ]] && _in_default=1 && break
      done
      [[ $_in_default -eq 0 ]] && _optin_names+=("$name")
    done
    if [[ ${#_optin_names[@]} -gt 0 ]]; then
      local _sorted_optin
      _sorted_optin=()
      while IFS= read -r _t; do
        [[ -n "$_t" ]] && _sorted_optin+=("$_t")
      done < <(printf '%s\n' "${_optin_names[@]}" | sort)
      FINAL_TOOLS+=("${_sorted_optin[@]}")
    fi

  elif [[ $ARG_SKIP_SET -eq 1 ]]; then
    validate_csv_shape "$ARG_SKIP"
    local skip_list=()
    IFS=',' read -ra skip_list <<< "$ARG_SKIP"
    # Validate each skip name against AvailableTools
    local name avail found
    for name in "${skip_list[@]}"; do
      found=0
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
    local tool skip s
    for tool in "${DEFAULT_TOOLS[@]}"; do
      skip=0
      for s in "${skip_list[@]}"; do
        [[ "$s" == "$tool" ]] && skip=1 && break
      done
      if [[ $skip -eq 0 ]]; then
        FINAL_TOOLS+=("$tool")
      fi
    done

  else
    FINAL_TOOLS=("${DEFAULT_TOOLS[@]}")
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

  if is_interactive; then
    if [[ $ARG_SELECTION_FILE_SET -eq 1 ]]; then
      # CI/test seam: read newline-delimited selection from file
      _MENU_SELECTION=""
      _MENU_CANCELLED=0
      local _sel_line
      while IFS= read -r _sel_line || [[ -n "$_sel_line" ]]; do
        _sel_line="${_sel_line%$'\r'}"
        [[ -z "$_sel_line" ]] && continue
        _MENU_SELECTION="${_MENU_SELECTION:+${_MENU_SELECTION},}${_sel_line}"
      done < "$ARG_SELECTION_FILE"
    else
      local _avail_for_menu=()
      local _t
      while IFS= read -r _t; do
        [[ -n "$_t" ]] && _avail_for_menu+=("$_t")
      done < <(get_available_tools)
      show_tool_menu DEFAULT_TOOLS _avail_for_menu
    fi

    if [[ "${_MENU_CANCELLED:-0}" -eq 1 ]]; then
      exit 0
    fi
    if [[ -z "${_MENU_SELECTION:-}" ]]; then
      log_info "Nothing selected, exiting."
      exit 0
    fi
    ARG_ONLY="$_MENU_SELECTION"
    ARG_ONLY_SET=1
  fi

  build_final_toolset

  local tool
  for tool in "${FINAL_TOOLS[@]}"; do
    run_tool "$tool"
  done

  log_ok "Setup complete. Open a new shell to apply all changes."
}

main
