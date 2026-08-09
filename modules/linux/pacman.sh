# @module pacman
# @summary Arch Linux package maintenance: orphan cleanup and cache pruning.
#
# The old shellrc.d/pacman.sh also carried two non-pacman helpers, `ptimer` and
# `try`. Both moved to modules/common/shell.sh as shell_time_command and
# shell_retry — they are portable, and `try` both shadowed a real binary and
# called `exit` on success, which killed the interactive shell that sourced it.

require pacman || return 0

# @describe List packages that were pulled in as dependencies and are no longer
#           required by anything.
# @usage    pacman_list_orphans
# @example  pacman_list_orphans
# @requires pacman
# @os       linux
pacman_list_orphans() {
    pacman -Qtdq
}

# @describe Remove every orphaned package, along with its dependencies and
#           configuration files.
# @usage    pacman_remove_orphans
# @example  pacman_remove_orphans
# @requires pacman
# @danger   Uninstalls packages. Read the list before saying yes.
# @os       linux
# @see      pacman_list_orphans
pacman_remove_orphans() {
    local orphans
    orphans=$(pacman_list_orphans)
    if [ -z "$orphans" ]; then
        log_ok "No orphaned packages."
        return 0
    fi

    log_info "Orphaned packages:"
    printf '%s\n' "$orphans" >&2
    confirm "Remove all of these?" || return 0

    # Word splitting is intended here: pacman wants one argument per package.
    # shellcheck disable=SC2086
    sudo pacman -Rns $orphans
}

# @describe Prune old package versions from the pacman cache. Keeps the
#           currently installed versions.
# @usage    pacman_clean_cache
# @example  pacman_clean_cache
# @requires pacman
# @danger   Deletes cached packages, so downgrading later means re-downloading.
# @os       linux
# @see      https://wiki.archlinux.org/index.php/pacman#Cleaning_the_package_cache
pacman_clean_cache() {
    log_info "Cache size before: $(path_size /var/cache/pacman/pkg)"
    confirm "Remove all cached versions except the installed ones?" || return 0
    sudo pacman -Sc
    log_ok "Cache size after: $(path_size /var/cache/pacman/pkg)"
}

alias pm='pacman'
