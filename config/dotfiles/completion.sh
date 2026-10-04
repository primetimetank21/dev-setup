# DevSetup opt-in completion. Sourced by the separate completion rc hook.
# Bash 3.2+ / Zsh. No effect in noninteractive shells or when disabled.
# shellcheck shell=bash
case $- in *i*) ;; *) return 0 ;; esac
[ "${DEV_SETUP_COMPLETION:-1}" != 0 ] || return 0

_dev_setup_completion() {
    local map widgets
    if [ -n "${BASH_VERSION:-}" ]; then
        widgets=$'\n'"$(bind -l)"$'\n'
        case "$widgets" in *$'\nmenu-complete\n'*) ;; *) return 1 ;; esac
        for map in emacs-standard vi-insert; do
            bind -m "$map" '"\C-i": menu-complete'
            # Readline 5.2 (macOS Bash 3.2) has no backward widget. Leave the
            # existing Shift+Tab binding alone; do not reserve extra keys.
            case "$widgets" in
                *$'\nmenu-complete-backward\n'*)
                    bind -m "$map" '"\e[Z": menu-complete-backward' ;;
            esac
        done
    elif [ -n "${ZSH_VERSION:-}" ]; then
        # These are native widgets even without compinit. If a framework has
        # initialized completion, the same widget names use its providers.
        # Do not run compinit here: it also changes unrelated key bindings.
        # Users/frameworks retain responsibility for its normal security audit.
        for map in emacs viins; do
            bindkey -M "$map" '^I' menu-complete
            bindkey -M "$map" '^[[Z' reverse-menu-complete
        done
    fi
}
_dev_setup_completion
unset -f _dev_setup_completion
