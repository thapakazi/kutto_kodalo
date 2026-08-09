# @module shell
# @summary Interactive shell baseline: locale, editor/pager, vi keybindings,
#          unlimited shared history, and a few generic command helpers.
#
# Replaces the old generic.sh, defaults.sh, env_vars.sh, core.sh, common.sh and
# shell-history.sh. Everything here is either a variable assignment, a function
# definition, or a shell option — nothing forks a process at load time.

# ------------------------------------------------------------------ locale --
#
# LANG only. The old generic.sh also exported LC_ALL, which is a sledgehammer:
# it overrides every LC_* category and cannot be selectively overridden by the
# user afterwards (so `LC_TIME=en_GB.UTF-8 date` silently does nothing). Set the
# default with LANG and leave LC_ALL unset so individual categories stay tunable.
export LANG="${LANG:-en_US.UTF-8}"

# ------------------------------------------------------------------ editor --

export EDITOR="${EDITOR:-emacs}"
export VISUAL="${VISUAL:-$EDITOR}"

# ------------------------------------------------------------------- pager --
#
# Highlight section titles in man pages. This deliberately uses a literal escape
# rather than $C_B_YELLOW: lib/10-colors.sh blanks the C_* names when the shell
# was started without a tty, but man is rendered later, when there is one. (The
# original generic.sh used "$yellow", a variable that was never defined
# anywhere — the old colors.sh spelled it "Yellow" — so this was silently empty.)
export LESS_TERMCAP_md=$'\033[1;33m'
export LESS_TERMCAP_me=$'\033[0m'

# MANPAGER tradeoff: the original was `less -X`, which keeps the page on screen
# after you quit. -X does that by refusing to use the terminal's alternate
# screen — which also breaks mouse-wheel scrolling and leaves the scrollback
# polluted in every modern terminal. Default is the well-behaved variant; to get
# the old behaviour back, set MANPAGER='less -X' in modules/local/.
export MANPAGER="${MANPAGER:-less -R}"

# ---------------------------------------------------------------- user agent --

# Handy for `curl -A "$FIREFOX_UA"` when a site refuses the default curl agent.
export FIREFOX_UA='Mozilla/5.0 (X11; Linux x86_64; rv:50.0) Gecko/20100101 Firefox/50.0'

# ----------------------------------------------------------------- vi mode --
#
# NOTE: this is a surprising global. It puts the *line editor* into vi mode in
# both bash and zsh, so <Esc> leaves insert mode and hjkl navigate the line.
# Emacs-style bindings (C-a, C-e, C-r) mostly still work in insert mode. If you
# ever wonder why your shell "stopped responding to arrow keys after Esc", this
# is why: `set -o emacs` undoes it for the current session.
set -o vi

# ---------------------------------------------------------------- history --

# @describe Configure effectively unlimited, timestamped, cross-session shell
#           history for whichever shell is running. Idempotent — safe to call
#           again after re-sourcing.
# @usage    shell_setup_history
# @example  shell_setup_history
# @os       any
shell_setup_history() {
    if [ -n "$ZSH_VERSION" ]; then
        export HISTSIZE=1000000000        # zsh has no -1 sentinel
        export SAVEHIST=1000000000
        export HISTFILE="${HISTFILE:-$HOME/.zsh_history}"

        setopt INC_APPEND_HISTORY         # write as you go, not just on exit
        setopt SHARE_HISTORY              # visible in every open window
        setopt EXTENDED_HISTORY           # record timestamps
        setopt HIST_IGNORE_ALL_DUPS       # keep only the most recent duplicate
    elif [ -n "$BASH_VERSION" ]; then
        # -1 means unlimited, but only in bash 4.3+. macOS still ships 3.2,
        # where it is just a weird number, so fall back to a large integer.
        if [ "${BASH_VERSINFO[0]:-0}" -gt 4 ] ||
           { [ "${BASH_VERSINFO[0]:-0}" -eq 4 ] && [ "${BASH_VERSINFO[1]:-0}" -ge 3 ]; }; then
            export HISTSIZE=-1
            export HISTFILESIZE=-1
        else
            export HISTSIZE=1000000
            export HISTFILESIZE=1000000
        fi
        export HISTFILE="${HISTFILE:-$HOME/.bash_history}"
        export HISTCONTROL=ignoreboth
        export HISTTIMEFORMAT="%F %T "
        shopt -s histappend

        # Sync across open sessions. The original unconditionally prepended to
        # PROMPT_COMMAND, so every re-source grew it by another copy and the
        # variable expanded without bound. Only add the hook if it is absent.
        case "$PROMPT_COMMAND" in
            *"history -a"*) : ;;
            "")  PROMPT_COMMAND="history -a; history -n" ;;
            *)   PROMPT_COMMAND="history -a; history -n; $PROMPT_COMMAND" ;;
        esac
    fi
}

# Setting shell options at load time is what a config module is for; this forks
# nothing and is idempotent.
shell_setup_history

# --------------------------------------------------------------- reloading --

# @describe Re-source ~/.shellrc, picking up edits without opening a new shell.
# @usage    shell_reload
# @example  shell_reload
# @os       any
shell_reload() {
    if [ -f "$HOME/.shellrc" ]; then
        # shellcheck disable=SC1091
        . "$HOME/.shellrc" && log_ok "reloaded ~/.shellrc"
    else
        log_error "no ~/.shellrc found — run bin/bootstrap first"
    fi
}

# ------------------------------------------------------- preferred programs --

# @describe Print the editor command this machine should use. Honours $EDITOR
#           and falls back to emacs. Other modules call this instead of
#           hardcoding a name.
# @usage    shell_get_editor
# @example  $(shell_get_editor) ~/notes.org
# @os       any
shell_get_editor() {
    printf '%s\n' "${EDITOR:-emacs}"
}

# @describe Print the browser command this machine should use. Honours $BROWSER
#           and falls back to the first graphical browser found.
# @usage    shell_get_browser
# @example  $(shell_get_browser) https://example.com
# @os       any
shell_get_browser() {
    if [ -n "$BROWSER" ]; then
        printf '%s\n' "$BROWSER"
        return 0
    fi
    local candidate
    for candidate in brave brave-browser firefox chromium google-chrome; do
        if has "$candidate"; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    printf '%s\n' "Brave-Browser"      # historical default; nothing else found
}

# ----------------------------------------------------------- command helpers --

# @describe Re-run a command until it succeeds, at most N times (default:
#           forever). Rescued from the old pacman.sh `try`, which was named
#           after a real binary and — fatally for a sourced file — called `exit`
#           on success, killing the interactive shell it was invoked from.
# @usage    shell_retry [count] <command> [args...]
# @example  shell_retry 5 curl -fsS https://example.com
# @example  shell_retry ping -c1 gateway
# @os       any
shell_retry() {
    local count=-1 rc=0
    case "$1" in
        ''|*[!0-9]*) : ;;
        *) count="$1"; shift ;;
    esac
    [ $# -gt 0 ] || { log_error "shell_retry: nothing to run"; return 2; }

    while [ "$count" -ne 0 ]; do
        "$@"
        rc=$?
        [ "$rc" -eq 0 ] && return 0
        count=$((count - 1))
    done
    return "$rc"
}

# @describe Time a command in whole seconds without needing bc or GNU date.
# @usage    shell_time_command <command> [args...]
# @example  shell_time_command sleep 2
# @os       any
shell_time_command() {
    [ $# -gt 0 ] || { log_error "shell_time_command: nothing to run"; return 2; }
    local start end rc
    start=$(date +%s)
    "$@"
    rc=$?
    end=$(date +%s)
    log_info "took $((end - start))s"
    return "$rc"
}

# @describe Serve the current directory over HTTP. Salvaged from rhoit/rho.sh,
#           whose other entries all shadowed real binaries and were retired.
# @usage    shell_serve_http [port]
# @example  shell_serve_http 8000
# @requires python3
# @os       any
shell_serve_http() {
    require python3 || return 0
    local port="${1:-8000}"
    log_info "serving $PWD on http://localhost:$port"
    python3 -m http.server "$port"
}

# -------------------------------------------------- percol history (zsh) ----
#
# Ctrl-R through percol. The old percol.sh defined a global helper called
# `exists` and bound the key whenever percol was installed, in bash too — where
# `zle` and `bindkey` do not exist. Guarded on both conditions now.
#
# See the note in the port report: fzf ships its own, better, Ctrl-R widget, and
# if you install fzf you should let it own this binding instead.
if [ -n "$ZSH_VERSION" ] && has percol; then
    shell_percol_history() {
        local reverse
        if   has gtac; then reverse=gtac
        elif has tac;  then reverse=tac
        else                reverse="tail -r"
        fi
        BUFFER=$(fc -l -n 1 | eval "$reverse" | percol --query "$LBUFFER")
        CURSOR=$#BUFFER
        zle -R -c
    }
    zle -N shell_percol_history
    bindkey '^R' shell_percol_history
fi

# ------------------------------------------------------------------ aliases --

alias reload_shellrc='shell_reload'
alias my_editor='shell_get_editor'
alias my_browser='shell_get_browser'
alias pysrv='shell_serve_http'

# Root shells. `susu` is a login shell as root — it reads root's profile, unlike
# plain `sudo -s`, so PATH and umask are root's rather than yours.
alias susu='sudo su -'

# Was `tailf.ngxinx` — a typo, and a dot is not a legal function-name character.
alias tailf_nginx='tail -f /var/log/nginx/*.log'

# All-day, all-night emacs. Typo insurance; these expand to the real binary.
alias eamcs='emacs'
alias emasc='emacs'
alias emcas='emacs'
alias emcsa='emacs'
alias meacs='emacs'
