# @module files
# @summary Filesystem chores: disk usage, directory creation, locating things on
#          disk, and reclaiming space from node_modules trees.

# ------------------------------------------------------------- disk usage ----

# @describe Print the size of each given path, human readable, smallest first.
#           With no arguments it measures every entry in the current directory,
#           dotfiles included, without ever walking up into the parent.
# @usage    files_disk_usage [path]...
# @example  files_disk_usage
# @example  files_disk_usage ~/Downloads ~/Movies
# @os       any
# @see      path_size
files_disk_usage() {
    if [ $# -gt 0 ]; then
        du -sh -- "$@" 2>/dev/null | sort -h
    else
        # -mindepth 1 is what keeps '.' and '..' out of the listing; the old
        # `du -sh .*` walked the whole parent tree.
        find . -mindepth 1 -maxdepth 1 -exec du -sh {} + 2>/dev/null | sort -h
    fi
}

# --------------------------------------------------------- making directories -

# @describe Create a directory (with parents) and change into it.
# @usage    files_mkcd <directory>
# @example  files_mkcd ~/scratch/experiment
# @os       any
files_mkcd() {
    [ -n "$1" ] || { log_error "usage: files_mkcd <directory>"; return 1; }
    mkdir -p -- "$1" && cd -- "$1" || return 1
}

# @describe Create a timestamped directory and print its path. Useful for dump
#           and capture directories that must not collide.
# @usage    files_mkdir_dated [prefix]
# @example  files_mkdir_dated tcpdump
# @os       any
files_mkdir_dated() {
    local prefix="${1:-dump}" dir
    dir="${prefix}_$(timestamp)"
    mkdir -p -- "$dir" || return 1
    printf '%s\n' "$dir"
}

# ------------------------------------------------------------ where is it ----

# @describe Long-list every real file a command name resolves to on PATH, so you
#           can see symlinks, permissions and shim wrappers at a glance.
# @usage    files_list_command_path <command>
# @example  files_list_command_path python3
# @os       any
files_list_command_path() {
    local cmd="$1" p found=0
    [ -n "$cmd" ] || { log_error "usage: files_list_command_path <command>"; return 1; }
    while IFS= read -r p; do
        [ -e "$p" ] || continue          # zsh's `which -a` also prints function bodies
        ls -la -- "$p"
        found=1
    done <<EOF
$(which -a "$cmd" 2>/dev/null)
EOF
    [ "$found" -eq 1 ] || { log_error "files_list_command_path: no file on PATH for: $cmd"; return 1; }
}

# @describe Print the file and line number where a shell function was defined.
#           Works in both shells: zsh answers from `whence`, bash needs the
#           extdebug option toggled around `declare -F`.
# @usage    files_locate_function <function-name>
# @example  files_locate_function files_mkcd
# @os       any
files_locate_function() {
    local fn="$1" rc=0 had_extdebug=0
    [ -n "$fn" ] || { log_error "usage: files_locate_function <function-name>"; return 1; }
    if [ -n "$ZSH_VERSION" ]; then
        whence -v "$fn"
        return $?
    fi
    shopt -q extdebug && had_extdebug=1
    shopt -s extdebug
    declare -F "$fn"
    rc=$?
    [ "$had_extdebug" -eq 1 ] || shopt -u extdebug
    return $rc
}

# ----------------------------------------------------------- node_modules ----

# @describe List every node_modules directory below the current directory with
#           its size, largest last. The result is cached per directory because
#           the scan is slow; pass --refresh to rescan.
# @usage    files_find_node_modules [--refresh]
# @example  files_find_node_modules
# @example  files_find_node_modules --refresh
# @os       any
files_find_node_modules() {
    local cache_dir cache key refresh=0
    case "$1" in
        -r | --refresh) refresh=1 ;;
        '') : ;;
        *) log_error "usage: files_find_node_modules [--refresh]"; return 1 ;;
    esac

    cache_dir="${SHELLRC_CACHE:-${TMPDIR:-/tmp}}"
    mkdir -p -- "$cache_dir" 2>/dev/null || cache_dir="${TMPDIR:-/tmp}"
    # key the cache on the directory being scanned — one shared /tmp file meant
    # the first project you scanned was the answer for every project after it
    key=$(printf '%s' "$PWD" | cksum | awk '{print $1}')
    cache="$cache_dir/node-modules-$key.list"

    if [ "$refresh" -eq 0 ] && [ -s "$cache" ]; then
        cat -- "$cache"
        return 0
    fi

    find . -name node_modules -type d -prune -print0 2>/dev/null \
        | xargs -0 du -sh 2>/dev/null \
        | sort -h \
        | tee -- "$cache"
}

# @describe Delete every node_modules directory below the current directory.
#           Any arguments are treated as extended-regex patterns for paths to
#           KEEP. Prints the full list and asks before removing anything.
# @usage    files_purge_node_modules [keep-pattern]...
# @example  files_purge_node_modules
# @example  files_purge_node_modules work/ important-project
# @os       any
# @danger   Recursively deletes directories. Confirms once, then removes them all.
# @see      files_find_node_modules
files_purge_node_modules() {
    # NB: never name a local `path` here — zsh ties $path to $PATH, so a local
    # of that name blanks PATH for the whole call.
    local keep listing size target

    listing=$(files_find_node_modules --refresh) || return 1

    if [ $# -gt 0 ]; then
        keep=$(printf '%s|' "$@" | sed 's/|$//')
        # an unset pattern used to reach grep as an empty string, which matches
        # everything and silently emptied the kill list
        listing=$(printf '%s\n' "$listing" | grep -Ev -- "$keep")
    fi

    if [ -z "$listing" ]; then
        log_info "No node_modules directories to remove."
        return 0
    fi

    log_warn "These directories will be deleted:"
    printf '%s\n' "$listing"
    printf '%s\n' '------------------------'
    confirm "Delete every directory listed above?" || { log_info "No harm done."; return 0; }

    # du -sh emits "<size><TAB><path>"; splitting on TAB alone keeps paths that
    # contain spaces intact. The old `xargs -I {} echo removing {} && rm -rf {}`
    # only echoed, then ran `rm -rf` once against a literal "{}".
    # shellcheck disable=SC2034  # `size` exists only to consume the first field
    printf '%s\n' "$listing" | while IFS=$'\t' read -r size target; do
        [ -n "$target" ] || continue
        [ -d "$target" ] || continue
        log_info "removing $target"
        rm -rf -- "$target"
    done
}

# ------------------------------------------------------------ back-compat ----
# Old names kept as aliases so muscle memory survives. The long name is the API.

alias dush='files_disk_usage'
alias dushd='files_disk_usage'
alias duh='files_disk_usage'
alias mkcd='files_mkcd'
alias mkdir_with_date='files_mkdir_dated'
alias lsich='files_list_command_path'
alias whereis_func='files_locate_function'
alias find_all_node_modules='files_find_node_modules'
alias find_all_node_modules_raw='files_find_node_modules --refresh'
alias find_and_nuke_node_modules='files_purge_node_modules'
