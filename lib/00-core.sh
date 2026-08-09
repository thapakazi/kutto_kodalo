# @module core
# @summary Dependency guards, logging, and shell introspection used by every module.

# Tools a module asked for but that are not installed. `doctor` reports these.
SHELLRC_MISSING_DEPS=""

# @describe Test whether a command exists on PATH.
# @usage    has <command>
# @example  has jq && jq . file.json
# @os       any
has() {
    command -v "$1" >/dev/null 2>&1
}

# @describe Guard a module on its external dependencies. Records anything missing
#           for `doctor` and returns non-zero so the caller can bail out early.
# @usage    require <command>...
# @example  require docker jq || return 0
# @os       any
require() {
    local cmd missing=0
    for cmd in "$@"; do
        if ! has "$cmd"; then
            case " $SHELLRC_MISSING_DEPS " in
                *" $cmd "*) : ;;
                *) SHELLRC_MISSING_DEPS="$SHELLRC_MISSING_DEPS $cmd" ;;
            esac
            missing=1
        fi
    done
    return $missing
}

# @describe Same as `require`, but satisfied when ANY one of the alternatives exists.
#           Use for interchangeable tools (pbcopy vs xclip vs wl-copy).
# @usage    require_any <command>...
# @example  require_any pbcopy xclip wl-copy || return 0
# @os       any
require_any() {
    local cmd
    for cmd in "$@"; do
        has "$cmd" && return 0
    done
    SHELLRC_MISSING_DEPS="$SHELLRC_MISSING_DEPS $(printf '%s|' "$@" | sed 's/|$//')"
    return 1
}

# @describe Print an informational message to stderr.
# @usage    log_info <message>...
# @os       any
log_info() { printf '%s%s%s\n' "$C_BLUE" "$*" "$C_RESET" >&2; }

# @describe Print a success message to stderr.
# @usage    log_ok <message>...
# @os       any
log_ok() { printf '%s%s%s\n' "$C_GREEN" "$*" "$C_RESET" >&2; }

# @describe Print a warning to stderr.
# @usage    log_warn <message>...
# @os       any
log_warn() { printf '%s%s%s\n' "$C_YELLOW" "$*" "$C_RESET" >&2; }

# @describe Print an error to stderr and return 1.
# @usage    log_error <message>...
# @os       any
log_error() { printf '%s%s%s\n' "$C_RED" "$*" "$C_RESET" >&2; return 1; }

# @describe Prompt for y/N confirmation. Returns 0 only on an explicit yes.
#           Defaults to NO on empty input, EOF, or anything unrecognised.
# @usage    confirm <prompt>
# @example  confirm "Delete 40GB of caches?" || return 0
# @os       any
confirm() {
    # NB: not `local prompt` — zsh ties `prompt` to PS1. See docs/CONVENTIONS.md.
    local message="${1:-Are you sure?}" reply=""
    if [ -n "$ZSH_VERSION" ]; then
        read "reply?$(printf '%s%s%s [y/N]: ' "$C_CYAN" "$message" "$C_RESET")" || return 1
    else
        read -r -p "$(printf '%s%s%s [y/N]: ' "$C_CYAN" "$message" "$C_RESET")" reply || return 1
    fi
    case "$reply" in
        [yY] | [yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

# @describe Print the name of the current shell: zsh, bash, or unknown.
# @usage    current_shell
# @os       any
current_shell() {
    if [ -n "$ZSH_VERSION" ]; then echo zsh
    elif [ -n "$BASH_VERSION" ]; then echo bash
    else echo unknown
    fi
}
