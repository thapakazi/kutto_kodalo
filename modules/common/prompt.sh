# @module prompt
# @summary Git-aware zsh prompt with abbreviated paths, plus AWS/Kubernetes
#          context on the right and a cursor-shape vi-mode indicator.
#
# Left:   [✗rc ]repo:/s/d/current branch[*]$
# Right:  aws:<profile>  k8s:<context>       (only when those are set)
#
# The path reads `project:/s/d/current` — repo name, intermediate directories
# squashed to one letter each, current directory spelled out.
#
# Cost: all state is computed once per prompt in precmd, not per redraw, and the
# whole thing is ONE `git` fork. The kube context is read from the kubeconfig
# file directly (no `kubectl` fork) and re-read only when its mtime changes.
#
# Knobs, set in modules/local/:
#   SHELLRC_PROMPT=off          keep your own PROMPT entirely
#   SHELLRC_PROMPT_DIRTY=off    skip the `git status` dirty check (see below)
#   SHELLRC_PROMPT_CONTEXT=off  hide the right-hand aws/k8s side
#   SHELLRC_PROMPT_CURSOR=off   don't touch the cursor shape
#
# zsh only. Sourcing from bash is a no-op rather than an error.

[ -n "$ZSH_VERSION" ] || return 0
[ "$SHELLRC_PROMPT" = "off" ] && return 0

setopt PROMPT_SUBST

zmodload -F zsh/stat b:zstat 2>/dev/null

# Cached per-prompt state, refreshed by _prompt_precmd.
_PROMPT_RC=0
_PROMPT_GIT_ROOT=""
_PROMPT_GIT_BRANCH=""
_PROMPT_GIT_DIRTY=""
_PROMPT_KUBE_CTX=""
_PROMPT_KUBE_SRC=""
_PROMPT_KUBE_MTIME=""

# Read `current-context` straight out of the kubeconfig. Avoids a `kubectl`
# fork (~30-80ms) on every prompt. Only re-reads when the file's mtime changes.
# Note: with multiple colon-separated KUBECONFIG entries only the first readable
# file is consulted, which is what kubectl reports in the common single-file case.
_prompt_kube_context() {
    local cfg line mtime
    cfg="${KUBECONFIG%%:*}"
    [ -n "$cfg" ] || cfg="$HOME/.kube/config"

    if [ ! -r "$cfg" ]; then
        _PROMPT_KUBE_CTX="" _PROMPT_KUBE_SRC="" _PROMPT_KUBE_MTIME=""
        return
    fi

    mtime=$(zstat +mtime "$cfg" 2>/dev/null) || mtime=""
    if [ "$cfg" = "$_PROMPT_KUBE_SRC" ] && [ "$mtime" = "$_PROMPT_KUBE_MTIME" ]; then
        return                                  # cache still valid
    fi
    _PROMPT_KUBE_SRC="$cfg" _PROMPT_KUBE_MTIME="$mtime" _PROMPT_KUBE_CTX=""

    while IFS= read -r line; do
        case "$line" in
            'current-context:'*)
                line="${line#current-context:}"
                line="${line//[[:space:]]/}"
                line="${line//\"/}"
                line="${line//\'/}"
                _PROMPT_KUBE_CTX="$line"
                break
                ;;
        esac
    done < "$cfg"
}

# Refresh everything the prompt needs. Runs once per command, not per redraw.
_prompt_precmd() {
    _PROMPT_RC=$?                               # MUST be the very first line

    local info
    _PROMPT_GIT_ROOT="" _PROMPT_GIT_BRANCH="" _PROMPT_GIT_DIRTY=""

    # One fork for both values: toplevel on line 1, branch on line 2.
    if info=$(command git rev-parse --show-toplevel --abbrev-ref HEAD 2>/dev/null); then
        _PROMPT_GIT_ROOT="${info%%$'\n'*}"
        _PROMPT_GIT_BRANCH="${info##*$'\n'}"
        [ "$_PROMPT_GIT_BRANCH" = "HEAD" ] && _PROMPT_GIT_BRANCH="detached"

        # The dirty check is a second fork and is the classic cause of prompt lag
        # in very large repositories. Disable with SHELLRC_PROMPT_DIRTY=off.
        if [ "$SHELLRC_PROMPT_DIRTY" != "off" ] && [ -n "$_PROMPT_GIT_ROOT" ]; then
            if [ -n "$(command git status --porcelain --ignore-submodules=dirty 2>/dev/null | head -1)" ]; then
                _PROMPT_GIT_DIRTY="*"
            fi
        fi
    fi

    [ "$SHELLRC_PROMPT_CONTEXT" != "off" ] && _prompt_kube_context
}

# @describe Build the left-hand prompt string: failure marker, repo name,
#           abbreviated path, branch and dirty marker. Reads state cached by
#           precmd, so it costs no forks at redraw time.
# @usage    prompt_build_string
# @example  prompt_build_string
# @requires git
# @os       any
prompt_build_string() {
    local out="" rel part rest abbrev

    [ "$_PROMPT_RC" != 0 ] && out="%F{red}✗${_PROMPT_RC}%f "

    if [ -z "$_PROMPT_GIT_ROOT" ]; then
        print -r -- "${out}%F{yellow}%c%f\$ "
        return 0
    fi

    rel="${PWD#"$_PROMPT_GIT_ROOT"}"
    rel="${rel#/}"
    rel="${rel%/}"

    if [ -z "$rel" ]; then
        out="${out}%F{cyan}${_PROMPT_GIT_ROOT:t}%f"
    else
        # Abbreviate every component but the last to its first character.
        abbrev="" rest="$rel"
        while [ "$rest" != "${rest#*/}" ]; do
            part="${rest%%/*}"
            abbrev="$abbrev/${part%"${part#?}"}"
            rest="${rest#*/}"
        done
        out="${out}%F{cyan}${_PROMPT_GIT_ROOT:t}:${abbrev}/${rest}%f"
    fi

    [ -n "$_PROMPT_GIT_BRANCH" ] && out="${out} %F{magenta}${_PROMPT_GIT_BRANCH}%f"
    [ -n "$_PROMPT_GIT_DIRTY" ]  && out="${out}%F{yellow}${_PROMPT_GIT_DIRTY}%f"

    print -r -- "${out}\$ "
}

# @describe Build the right-hand prompt: the active AWS profile and Kubernetes
#           context. Prints nothing when neither is set, so the line stays clean
#           until you are actually pointed at an account or a cluster.
# @usage    prompt_context_string
# @example  prompt_context_string
# @os       any
# @see      prompt_build_string
prompt_context_string() {
    [ "$SHELLRC_PROMPT_CONTEXT" = "off" ] && return 0
    local out=""
    [ -n "$AWS_PROFILE" ]     && out="%F{blue}aws:${AWS_PROFILE}%f"
    [ -n "$_PROMPT_KUBE_CTX" ] && out="${out:+$out }%F{green}k8s:${_PROMPT_KUBE_CTX}%f"
    print -r -- "$out"
}

# ------------------------------------------------------------ vi mode cursor --
# Block cursor in normal mode, bar in insert mode. Costs no prompt space.
# Reset to a bar before running a command so full-screen programs start sane.

if [ "$SHELLRC_PROMPT_CURSOR" != "off" ]; then
    _prompt_cursor() {
        case "$KEYMAP" in
            vicmd) printf '\e[2 q' ;;   # steady block
            *)     printf '\e[6 q' ;;   # steady bar
        esac
    }
    _prompt_cursor_reset() { printf '\e[6 q'; }

    # Chain rather than clobber: another plugin may already own these widgets.
    if [[ -n ${widgets[zle-keymap-select]} ]]; then
        functions[_prompt_orig_keymap]=${functions[zle-keymap-select]}
        zle-keymap-select() { _prompt_orig_keymap "$@"; _prompt_cursor; }
    else
        zle-keymap-select() { _prompt_cursor; }
    fi
    zle -N zle-keymap-select

    if [[ -n ${widgets[zle-line-init]} ]]; then
        functions[_prompt_orig_lineinit]=${functions[zle-line-init]}
        zle-line-init() { _prompt_orig_lineinit "$@"; _prompt_cursor; }
    else
        zle-line-init() { _prompt_cursor; }
    fi
    zle -N zle-line-init

    preexec_functions+=(_prompt_cursor_reset)
fi

# Register precmd FIRST so $? is still the user's command exit status.
precmd_functions=(_prompt_precmd ${precmd_functions[@]})

# Single-quoted on purpose: these run at redraw time, not load time.
PROMPT='$(prompt_build_string)'
RPROMPT='$(prompt_context_string)'

# ---- back-compat -------------------------------------------------------------
alias build_custom_prompt=prompt_build_string
