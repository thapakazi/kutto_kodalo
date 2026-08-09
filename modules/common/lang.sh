# @module lang
# @summary Language runtimes and version managers: Go, Ruby (chruby), Node (nvm),
#          Python (pip) and uv.
#
# Startup budget note: only PATH assignment happens when this file is sourced.
# Every expensive `source` — nvm.sh is the classic offender, commonly cited at
# 100-300ms, with chruby adding more — is deferred behind a stub function that
# loads the real tool on first use and then re-invokes itself. Nothing here
# writes to the filesystem or forks a process at load time; this file sources in
# roughly 0.4ms.

# ------------------------------------------------------------------ private --

# Idempotent PATH prepend. Silently does nothing when the directory is absent or
# already on PATH, so re-sourcing this file never duplicates an entry.
_lang_path_prepend() {
    local dir="$1"
    [ -n "$dir" ] || return 0
    [ -d "$dir" ] || return 0
    case ":$PATH:" in
        *":$dir:"*) return 0 ;;
    esac
    PATH="$dir:$PATH"
    export PATH
}

# Homebrew's prefix, resolved once and memoised. Never hardcoded: it is
# /opt/homebrew on Apple Silicon, /usr/local on Intel, and
# /home/linuxbrew/.linuxbrew on Linux.
_lang_brew_prefix() {
    if [ -z "$_LANG_BREW_PREFIX" ]; then
        if has brew; then
            _LANG_BREW_PREFIX="$(brew --prefix 2>/dev/null)"
        fi
        [ -n "$_LANG_BREW_PREFIX" ] || _LANG_BREW_PREFIX="-"
    fi
    [ "$_LANG_BREW_PREFIX" = "-" ] && return 1
    printf '%s\n' "$_LANG_BREW_PREFIX"
}

# Every plausible chruby install prefix. Checked with builtin tests only, so this
# is safe to run at source time. Deliberately not a single hardcoded
# /opt/homebrew path: that is Apple-Silicon-only and wrong on Intel and Linux.
#
# Linuxbrew is covered via HOMEBREW_PREFIX rather than a literal
# /home/linuxbrew/... path. On macOS /home is an autofs mount, and merely
# stat()ing anything under it costs ~15ms per call — two probes here were 30ms
# of pure shell startup on a machine that could never have had linuxbrew.
_lang_chruby_dir_static() {
    local dir=""
    for dir in \
        "${HOMEBREW_PREFIX:+$HOMEBREW_PREFIX/opt/chruby/share/chruby}" \
        "${HOMEBREW_PREFIX:+$HOMEBREW_PREFIX/share/chruby}" \
        /opt/homebrew/opt/chruby/share/chruby \
        /opt/homebrew/share/chruby \
        /usr/local/opt/chruby/share/chruby \
        /usr/local/share/chruby \
        /usr/share/chruby \
        "$HOME/.chruby/share/chruby"
    do
        [ -n "$dir" ] || continue
        if [ -r "$dir/chruby.sh" ]; then
            printf '%s\n' "$dir"
            return 0
        fi
    done
    return 1
}

# Same, but also consults `brew --prefix` for non-standard prefixes. Forks, so it
# is only ever called at runtime.
_lang_chruby_dir() {
    local prefix="" dir=""
    prefix="$(_lang_brew_prefix 2>/dev/null)"
    if [ -n "$prefix" ]; then
        for dir in "$prefix/opt/chruby/share/chruby" "$prefix/share/chruby"; do
            if [ -r "$dir/chruby.sh" ]; then
                printf '%s\n' "$dir"
                return 0
            fi
        done
    fi
    _lang_chruby_dir_static
}

# Resolve a usable pip. Prints the command name.
_lang_pip_bin() {
    if   has pip;  then printf 'pip\n'
    elif has pip3; then printf 'pip3\n'
    else return 1
    fi
}

# ---------------------------------------------------------------------- go ---

_lang_path_prepend "${ASDF_DATA_DIR:-$HOME/.asdf}/shims"

# @describe Fetch a Go module with verbose output. Thin wrapper kept for muscle
#           memory; prefer `go install pkg@version` for installing binaries.
# @usage    go_get_verbose <package>...
# @example  go_get_verbose github.com/spf13/cobra
# @requires go
# @os       any
go_get_verbose() {
    has go || { log_error "go_get_verbose: go is not installed"; return 1; }
    go get -v "$@"
}

# -------------------------------------------------------------------- ruby ---

RUBIES_HOME="${RUBIES_HOME:-$HOME/.rubies}"

# @describe Load chruby (and its auto-switching hook) into the current shell.
#           Called automatically the first time you run `chruby`; run it by hand
#           if you want directory-based .ruby-version switching to start working
#           before then.
# @usage    ruby_load_chruby
# @example  ruby_load_chruby && chruby 3.3.0
# @requires chruby
# @os       any
ruby_load_chruby() {
    local dir=""
    dir="$(_lang_chruby_dir)" || {
        log_error "ruby_load_chruby: chruby not found (looked under brew prefix, /usr/local, /usr/share, ~/.chruby)"
        return 1
    }
    unset -f chruby 2>/dev/null
    # shellcheck disable=SC1090,SC1091
    . "$dir/chruby.sh"
    if [ -r "$dir/auto.sh" ]; then
        # shellcheck disable=SC1090,SC1091
        . "$dir/auto.sh"
    fi
    return 0
}

# Lazy stub: loading chruby costs a source at every shell start, so pay for it
# only when a ruby is actually selected. chruby.sh redefines this function.
# Defined only when chruby is actually installed, so `has chruby` stays honest.
if _lang_chruby_dir_static >/dev/null 2>&1; then
    # shellrc-doc: ignore  (lazy-load stub, replaced on first call)
    chruby() {
        ruby_load_chruby || return 1
        chruby "$@"
    }
fi

# @describe Delete an installed ruby from RUBIES_HOME (default ~/.rubies).
#           Prompts before removing anything.
# @usage    ruby_remove_version <version-string>
# @example  ruby_remove_version ruby-3.1.4
# @danger   Recursively deletes the whole ruby install directory.
# @os       any
ruby_remove_version() {
    local version="$1" target=""

    if [ -z "$version" ]; then
        log_error "usage: ruby_remove_version <version-string>   (e.g. ruby-3.1.4)"
        return 1
    fi

    target="$RUBIES_HOME/$version"
    if [ ! -d "$target" ]; then
        log_warn "ruby_remove_version: no such ruby: $target"
        return 1
    fi

    confirm "Remove $target ($(path_size "$target"))?" || return 0
    rm -rf -- "$target" || return 1
    log_ok "Removed $target"
}

# -------------------------------------------------------------------- node ---

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

# @describe Source nvm into the current shell. Called automatically the first time
#           you run `nvm`; sourcing nvm.sh is the single most expensive thing a
#           shell startup can do, so it is never done at load time.
# @usage    node_load_nvm
# @example  node_load_nvm && nvm use --lts
# @requires nvm
# @os       any
node_load_nvm() {
    local nvm_sh="$NVM_DIR/nvm.sh"
    if [ ! -s "$nvm_sh" ]; then
        log_error "node_load_nvm: nvm not installed ($nvm_sh not found)"
        return 1
    fi
    unset -f nvm 2>/dev/null
    # shellcheck disable=SC1090,SC1091
    . "$nvm_sh"
    # nvm's completion script is bash-only; loading it under zsh writes to stderr.
    if [ -n "$BASH_VERSION" ] && [ -s "$NVM_DIR/bash_completion" ]; then
        # shellcheck disable=SC1090,SC1091
        . "$NVM_DIR/bash_completion"
    fi
    return 0
}

# Lazy stub. nvm.sh replaces this definition as soon as it is sourced. Defined
# only when nvm is actually installed, so `has nvm` stays honest.
if [ -s "$NVM_DIR/nvm.sh" ]; then
    # shellrc-doc: ignore  (lazy-load stub, replaced on first call)
    nvm() {
        node_load_nvm || return 1
        nvm "$@"
    }
fi

# ------------------------------------------------------------------ python ---

export PYTHONUSERBASE="${PYTHONUSERBASE:-$HOME/.pip}"

_lang_path_prepend "$PYTHONUSERBASE/bin"

# @describe Install packages into PYTHONUSERBASE (default ~/.pip) with verbose
#           output, creating the directory if it does not exist yet. A leading
#           "install" word is accepted and ignored, so `pip_install_user install
#           foo` and `pip_install_user foo` behave the same.
# @usage    pip_install_user <package>...
# @example  pip_install_user httpie
# @requires pip|pip3
# @os       any
pip_install_user() {
    local pip_bin=""

    pip_bin="$(_lang_pip_bin)" || {
        log_error "pip_install_user: neither pip nor pip3 is on PATH"
        return 1
    }

    [ "$1" = "install" ] && shift
    if [ "$#" -eq 0 ]; then
        log_error "usage: pip_install_user <package>..."
        return 1
    fi

    if [ ! -d "$PYTHONUSERBASE" ]; then
        mkdir -p "$PYTHONUSERBASE" || return 1
    fi

    log_info "Installing into $PYTHONUSERBASE"
    command "$pip_bin" install --user -v "$@"
}

# Completion generated by pip_generate_completion, one file per shell so a
# bash-flavoured script is never sourced into zsh.
SHELLRC_PIP_COMPLETION="${SHELLRC_CACHE:-$HOME/.cache/shellrc}/pip-completion.${ZSH_VERSION:+zsh}${BASH_VERSION:+bash}.sh"

# @describe Regenerate the cached pip tab-completion script for the current shell
#           and load it. This used to run on every shell start against a
#           hardcoded /usr/bin/pip that does not exist on macOS; it is now
#           explicit and only run when you ask for it.
# @usage    pip_generate_completion
# @example  pip_generate_completion
# @requires pip|pip3
# @os       any
pip_generate_completion() {
    local pip_bin="" shell_name="" cache_dir=""

    pip_bin="$(_lang_pip_bin)" || {
        log_error "pip_generate_completion: neither pip nor pip3 is on PATH"
        return 1
    }

    shell_name="$(current_shell)"
    case "$shell_name" in
        zsh | bash) : ;;
        *) log_error "pip_generate_completion: unsupported shell: $shell_name"; return 1 ;;
    esac

    cache_dir="${SHELLRC_CACHE:-$HOME/.cache/shellrc}"
    [ -d "$cache_dir" ] || mkdir -p "$cache_dir" || return 1

    if ! command "$pip_bin" completion "--$shell_name" > "$SHELLRC_PIP_COMPLETION"; then
        rm -f -- "$SHELLRC_PIP_COMPLETION"
        log_error "pip_generate_completion: '$pip_bin completion --$shell_name' failed"
        return 1
    fi

    # shellcheck disable=SC1090
    . "$SHELLRC_PIP_COMPLETION"
    log_ok "pip completion written to $SHELLRC_PIP_COMPLETION"
}

if [ -r "$SHELLRC_PIP_COMPLETION" ]; then
    # shellcheck disable=SC1090
    . "$SHELLRC_PIP_COMPLETION"
fi

# ---------------------------------------------------------------------- uv ---

# uv and `pip install --user` both drop executables in ~/.local/bin. Prepend it
# when it exists; uv_ensure_path creates it when it does not.
_lang_path_prepend "$HOME/.local/bin"

# @describe Create ~/.local/bin if missing and make sure it is on PATH. uv, pipx
#           and `cargo install` all install there.
# @usage    uv_ensure_path
# @example  uv_ensure_path && uv tool install ruff
# @os       any
uv_ensure_path() {
    local bin_dir="$HOME/.local/bin"
    if [ ! -d "$bin_dir" ]; then
        mkdir -p "$bin_dir" || return 1
        log_ok "Created $bin_dir"
    fi
    _lang_path_prepend "$bin_dir"
}

# ------------------------------------------------------------ back-compat ----
# Old names from shellrc.d/{golang,rubies,nvm,pip_function,uv}.sh.

alias gover='go_get_verbose'
alias clean_ruby='ruby_remove_version'
alias mypip='pip_install_user'
