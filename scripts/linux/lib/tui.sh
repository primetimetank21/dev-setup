#!/usr/bin/env bash
# scripts/linux/lib/tui.sh -- Interactive Bash checkbox menu (#495 Slice 2)
#
# Sourced by setup.sh; never executed directly.
#
# Public interface:
#   show_tool_menu  <default_tools_array_name> <available_tools_array_name>
#       Sets globals: _MENU_SELECTION (CSV), _MENU_CANCELLED (0|1)
#
# Test seams: set _TUI_ARROW_NAV_OVERRIDE=0|1 to force a specific nav path,
# and _TUI_COLOR_OVERRIDE=0|1 to force plain or colored rendering.
# ponytail: eval for bash 3.2 nameref compat; upgrade to local -n when 4.3 is minimum.

# ---------------------------------------------------------------------------
# _tui_color_enabled -- true when menu styling is safe, or test-forced.
# NO_COLOR always wins, including over the force-color test seam.
# ---------------------------------------------------------------------------
_tui_color_enabled() {
  [[ "${_TUI_COLOR_OVERRIDE:-}" == "0" ]] && return 1
  [[ -n "${NO_COLOR:-}" ]] && return 1
  [[ "${_TUI_COLOR_OVERRIDE:-}" == "1" ]] && return 0
  [[ -t 1 ]] || return 1
  [[ "${TERM:-}" != "dumb" ]] || return 1
  return 0
}

# Fixed native SGR styles. Each function emits plain ASCII text when disabled.
_tui_style_heading() {
  if _tui_color_enabled; then printf '\033[1;36m%s\033[0m' "$1"; else printf '%s' "$1"; fi
}
_tui_style_checked() {
  if _tui_color_enabled; then printf '\033[32m%s\033[0m' "$1"; else printf '%s' "$1"; fi
}
_tui_style_optin() {
  if _tui_color_enabled; then printf '\033[33m%s\033[0m' "$1"; else printf '%s' "$1"; fi
}
_tui_style_confirmation() {
  if _tui_color_enabled; then printf '\033[32m%s\033[0m' "$1"; else printf '%s' "$1"; fi
}
_tui_style_warning() {
  if _tui_color_enabled; then printf '\033[33m%s\033[0m' "$1"; else printf '%s' "$1"; fi
}

# ---------------------------------------------------------------------------
# _tui_render_list -- draw the full menu list to stdout
#   $1: cursor index (-1 = no cursor indicator)
#   $2: newline-separated tool names
#   $3: space-separated checked flags (0|1 per tool, same order as $2)
#   $4: space-separated is_default flags (0|1 per tool)
# ---------------------------------------------------------------------------
_tui_render_list() {
  local cursor="$1"
  local tools_nl="$2"
  local checked_sp="$3"
  local is_def_sp="$4"

  local checked_arr=() is_def_arr=()
  # shellcheck disable=SC2162
  IFS=' ' read -ra checked_arr <<< "$checked_sp"
  IFS=' ' read -ra is_def_arr  <<< "$is_def_sp"

  local i=0 tool checked is_def pointer label check_str
  while IFS= read -r tool; do
    [[ -z "$tool" ]] && { i=$((i+1)); continue; }
    checked="${checked_arr[$i]:-0}"
    is_def="${is_def_arr[$i]:-0}"
    if [[ "$checked" == "1" ]]; then check_str="[x]"; else check_str="[ ]"; fi
    if [[ "$is_def"  == "1" ]]; then label="(default)"; else label="(opt-in)"; fi
    if [[ "$cursor"  -eq "$i" ]]; then pointer=">"; else pointer=" "; fi
    if [[ "$pointer" == ">" ]]; then _tui_style_heading "$pointer"; else printf '%s' "$pointer"; fi
    printf ' '
    if [[ "$checked" == "1" ]]; then _tui_style_checked "$check_str"; else printf '%s' "$check_str"; fi
    printf ' %s  ' "$tool"
    if [[ "$is_def" == "1" ]]; then printf '%s' "$label"; else _tui_style_optin "$label"; fi
    printf '\n'
    i=$((i+1))
  done <<< "$tools_nl"
}

# ---------------------------------------------------------------------------
# show_tool_menu -- main entry point
#   $1: name of the defaults array variable (e.g. "DEFAULT_TOOLS")
#   $2: name of the available-tools array variable
#   Sets globals: _MENU_SELECTION (CSV of selected tools), _MENU_CANCELLED (0|1)
# ---------------------------------------------------------------------------
show_tool_menu() {
  local _defaults_name="$1"
  local _avail_name="$2"

  _MENU_SELECTION=""
  _MENU_CANCELLED=0

  # Read arrays via eval (bash 3.2 compat; no local -n)
  local defaults_csv avail_csv
  # shellcheck disable=SC2086
  eval "defaults_csv=\"\${${_defaults_name}[*]:-}\""
  # shellcheck disable=SC2086
  eval "avail_csv=\"\${${_avail_name}[*]:-}\""

  local def_arr=() avail_arr=()
  IFS=' ' read -ra def_arr   <<< "$defaults_csv"
  IFS=' ' read -ra avail_arr <<< "$avail_csv"

  # Build ordered tool list: defaults (pre-checked) then opt-ins (unchecked, sorted)
  local tools_nl="" checked_sp="" is_def_sp="" count=0

  local d
  for d in "${def_arr[@]}"; do
    [[ -z "$d" ]] && continue
    tools_nl="${tools_nl}${d}"$'\n'
    checked_sp="${checked_sp}1 "
    is_def_sp="${is_def_sp}1 "
    count=$((count+1))
  done

  # Collect opt-ins (available but not default), sort, then append
  local a in_def optin_nl=""
  for a in "${avail_arr[@]}"; do
    [[ -z "$a" ]] && continue
    in_def=0
    for d in "${def_arr[@]}"; do [[ "$d" == "$a" ]] && in_def=1 && break; done
    [[ $in_def -eq 0 ]] && optin_nl="${optin_nl}${a}"$'\n'
  done
  if [[ -n "$optin_nl" ]]; then
    local s
    while IFS= read -r s; do
      [[ -z "$s" ]] && continue
      tools_nl="${tools_nl}${s}"$'\n'
      checked_sp="${checked_sp}0 "
      is_def_sp="${is_def_sp}0 "
      count=$((count+1))
    done < <(printf '%s' "$optin_nl" | sort)
  fi

  [[ $count -eq 0 ]] && return 0

  # Version branch
  local _use_arrow=1
  if [[ -n "${_TUI_ARROW_NAV_OVERRIDE:-}" ]]; then
    _use_arrow="$_TUI_ARROW_NAV_OVERRIDE"
  else
    local _bmaj _bmin
    _bmaj="${BASH_VERSION%%.*}"
    _bmin="${BASH_VERSION#*.}"; _bmin="${_bmin%%.*}"
    (( _bmaj > 4 || (_bmaj == 4 && _bmin >= 2) )) || _use_arrow=0
  fi

  if [[ "$_use_arrow" == "1" ]]; then
    _tui_arrow_mode "$tools_nl" "$checked_sp" "$is_def_sp" "$count"
  else
    _tui_numbered_mode "$tools_nl" "$checked_sp" "$is_def_sp" "$count"
  fi
}

# ---------------------------------------------------------------------------
# _tui_arrow_redraw -- emit one in-place redraw: cursor-up N, clear-down, render
#   $1: count (number of list lines = cursor-up delta)
#   $2: cursor index
#   $3: tools_nl
#   $4: checked_arr space-joined
#   $5: is_def_sp
# ---------------------------------------------------------------------------
_tui_arrow_redraw() {
  local count="$1" cursor="$2" tools_nl="$3" checked_sp="$4" is_def_sp="$5"
  printf '\033[%dA' "$count"
  printf '\033[J'
  _tui_render_list "$cursor" "$tools_nl" "$checked_sp" "$is_def_sp"
}

# ---------------------------------------------------------------------------
# _tui_checked_toggle_all -- toggle-all: if every item checked, uncheck all;
#   otherwise check all. Prints the resulting space-separated 0|1 string.
#   $1: space-separated checked flags (e.g. "1 0 1")
#   $2: count
# ---------------------------------------------------------------------------
_tui_checked_toggle_all() {
  local checked_sp="$1" count="$2"
  local arr=()
  IFS=' ' read -ra arr <<< "$checked_sp"
  local all_on=1 f j
  for f in "${arr[@]}"; do [[ "$f" == "0" ]] && all_on=0 && break; done
  for j in $(seq 0 $((count-1))); do
    [[ $all_on -eq 1 ]] && arr[j]=0 || arr[j]=1
  done
  printf '%s' "${arr[*]}"
}

# ---------------------------------------------------------------------------
# _tui_arrow_handle_key -- pure key-dispatch for arrow mode (no TTY/globals).
#   $1: key string (may contain escape sequences)
#   $2: current cursor index
#   $3: count
#   $4: space-separated checked flags
# Prints pipe-delimited result: cursor|checked_sp|done|cancelled
#   done=1      -- Enter pressed; caller should stop the loop
#   cancelled=1 -- q/Q/ESC; caller should set _MENU_CANCELLED and return
# ---------------------------------------------------------------------------
_tui_arrow_handle_key() {
  local key="$1" cursor="$2" count="$3" checked_sp="$4"
  local arr=() done_=0 cancelled=0
  IFS=' ' read -ra arr <<< "$checked_sp"
  case "$key" in
    $'\033[A') cursor=$(( cursor > 0         ? cursor - 1 : 0          )) ;;
    $'\033[B') cursor=$(( cursor < count - 1 ? cursor + 1 : count - 1 )) ;;
    ' ')
      if [[ "${arr[cursor]}" == "1" ]]; then arr[cursor]=0; else arr[cursor]=1; fi ;;
    a|A)
      IFS=' ' read -ra arr <<< "$(_tui_checked_toggle_all "${arr[*]}" "$count")" ;;
    '') done_=1 ;;
    q|Q|$'\033') cancelled=1 ;;
  esac
  printf '%s|%s|%s|%s' "$cursor" "${arr[*]}" "$done_" "$cancelled"
}

# ---------------------------------------------------------------------------
# _tui_arrow_mode -- bash >= 4.2: arrow keys, Space, Enter, a/A=toggle-all,
#   q/ESC to cancel
# ---------------------------------------------------------------------------
_tui_arrow_mode() {
  local tools_nl="$1" checked_sp="$2" is_def_sp="$3" count="$4"
  local cursor=0

  local checked_arr=()
  IFS=' ' read -ra checked_arr <<< "$checked_sp"

  printf '\n'
  _tui_style_heading 'Arrow keys to move, Space to toggle, Enter to confirm, q/ESC to cancel.'
  printf '\n\n'
  _tui_render_list "$cursor" "$tools_nl" "${checked_arr[*]}" "$is_def_sp"

  local done_=0 k1 k2 k3 key
  while [[ $done_ -eq 0 ]]; do
    IFS= read -rsn1 k1 <>/dev/tty
    key="$k1"
    if [[ "$k1" == $'\033' ]]; then
      IFS= read -rsn1 -t0.1 k2 <>/dev/tty || k2=""
      IFS= read -rsn1 -t0.1 k3 <>/dev/tty || k3=""
      key="${k1}${k2}${k3}"
    fi

    local _kd
    _kd="$(_tui_arrow_handle_key "$key" "$cursor" "$count" "${checked_arr[*]}")"
    cursor="${_kd%%|*}"
    local _kd_rest="${_kd#*|}"
    IFS=' ' read -ra checked_arr <<< "${_kd_rest%%|*}"
    local _kd_done="${_kd_rest#*|}"
    local _kd_cancelled="${_kd_done#*|}"
    _kd_done="${_kd_done%%|*}"

    if [[ "$_kd_cancelled" == "1" ]]; then
      _MENU_CANCELLED=1
      printf '\n'
      _tui_style_warning 'Install cancelled.'
      printf '\n'
      return 0
    fi
    [[ "$_kd_done" == "1" ]] && done_=1

    if [[ $done_ -eq 0 ]]; then
      _tui_arrow_redraw "$count" "$cursor" "$tools_nl" "${checked_arr[*]}" "$is_def_sp"
    fi
  done

  local i=0 tool sel=""
  while IFS= read -r tool; do
    [[ -z "$tool" ]] && { i=$((i+1)); continue; }
    [[ "${checked_arr[$i]}" == "1" ]] && sel="${sel:+${sel},}${tool}"
    i=$((i+1))
  done <<< "$tools_nl"

  _tui_style_confirmation 'Selection confirmed.'
  printf '\n'
  _MENU_SELECTION="$sel"
}

# ---------------------------------------------------------------------------
# _tui_numbered_mode -- bash 3.2 fallback: type a number to toggle
# ---------------------------------------------------------------------------
_tui_numbered_mode() {
  local tools_nl="$1" checked_sp="$2" is_def_sp="$3" count="$4"

  local tool_arr=() checked_arr=() is_def_arr=()
  while IFS= read -r t; do [[ -n "$t" ]] && tool_arr+=("$t"); done <<< "$tools_nl"
  IFS=' ' read -ra checked_arr <<< "$checked_sp"
  IFS=' ' read -ra is_def_arr  <<< "$is_def_sp"

  _tui_numbered_render tool_arr checked_arr is_def_arr "$count"

  local done_=0 _input
  while [[ $done_ -eq 0 ]]; do
    IFS= read -r _input <>/dev/tty
    case "$_input" in
      '')
        done_=1
        ;;
      q|Q)
        _MENU_CANCELLED=1
        _tui_style_warning 'Install cancelled.'
        printf '\n'
        return 0
        ;;
      a|A)
        IFS=' ' read -ra checked_arr <<< "$(_tui_checked_toggle_all "${checked_arr[*]}" "$count")"
        _tui_numbered_render tool_arr checked_arr is_def_arr "$count"
        ;;
      *)
        if [[ "$_input" =~ ^[0-9]+$ ]]; then
          local idx=$(( _input - 1 ))
          if [[ $idx -ge 0 && $idx -lt $count ]]; then
            if [[ "${checked_arr[idx]}" == "1" ]]; then
              checked_arr[idx]=0
            else
              checked_arr[idx]=1
            fi
            _tui_numbered_render tool_arr checked_arr is_def_arr "$count"
          fi
        fi
        ;;
    esac
  done

  local i=0 sel=""
  for i in $(seq 0 $((count-1))); do
    [[ "${checked_arr[$i]}" == "1" ]] && sel="${sel:+${sel},}${tool_arr[$i]}"
  done
  _tui_style_confirmation 'Selection confirmed.'
  printf '\n'
  _MENU_SELECTION="$sel"
}

# ---------------------------------------------------------------------------
# _tui_numbered_render -- print the numbered list (called before each prompt)
#   Receives array NAMES for bash 3.2 compat (no local -n)
# ---------------------------------------------------------------------------
_tui_numbered_render() {
  local _tname="$1" _cname="$2" _dname="$3" _cnt="$4"
  printf '\n'
  _tui_style_heading 'Arrow keys unavailable (bash 3.2). Number to toggle, a=all, Enter=confirm, q=cancel.'
  printf '\n'
  local i check_str label _t _c _d
  for i in $(seq 0 $((_cnt-1))); do
    # shellcheck disable=SC2086
    eval "_t=\"\${${_tname}[$i]}\"; _c=\"\${${_cname}[$i]}\"; _d=\"\${${_dname}[$i]}\""
    if [[ "$_c" == "1" ]]; then check_str="[x]"; else check_str="[ ]"; fi
    if [[ "$_d" == "1" ]]; then label="(default)"; else label="(opt-in)"; fi
    printf '%d. ' "$((i+1))"
    if [[ "$_c" == "1" ]]; then _tui_style_checked "$check_str"; else printf '%s' "$check_str"; fi
    printf ' %s  ' "$_t"
    if [[ "$_d" == "1" ]]; then printf '%s' "$label"; else _tui_style_optin "$label"; fi
    printf '\n'
  done
  printf '\n> '
}
