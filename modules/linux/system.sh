# @module system
# @summary Linux-only machine maintenance: disk reclamation, package tarballs,
#          webcam, and finding a Raspberry Pi on the LAN.
#
# These were the last functions still living only in the old shellrc.d/ tree.
# Ported here so that tree can be retired.

is_linux || return 0

# @describe Report reclaimable disk space, then optionally free it: package
#           caches, Go module and build caches, yarn and yay caches, and the
#           systemd journal. Shows sizes and asks before deleting anything.
# @usage    system_free_disk_space
# @example  system_free_disk_space
# @requires du
# @os       linux
# @danger   Deletes package and build caches and vacuums the systemd journal to
#           one day of history. Everything removed is regenerable, but a later
#           rebuild or reinstall will have to download again.
# @see      path_size
system_free_disk_space() {
    local targets=() t
    # $HOME, never /home/$(whoami) — that assumption is wrong on any machine
    # where the home directory is not under /home.
    for t in \
        /var/cache/pacman/pkg \
        "$HOME/go/pkg/mod" \
        "$HOME/.cache/yarn" \
        "$HOME/.cache/yay" \
        "$HOME/.cache/go-build"
    do
        [ -e "$t" ] && targets+=("$t")
    done

    printf '%sReclaimable space%s\n' "$C_BOLD" "$C_RESET"
    if [ ${#targets[@]} -eq 0 ]; then
        log_info "nothing cached to reclaim"
    else
        for t in "${targets[@]}"; do
            printf '  %-44s %s\n' "${t#"$HOME"/}" "$(path_size "$t")"
        done
    fi
    has journalctl && printf '  %-44s %s\n' "systemd journal" \
        "$(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+[KMGT]?B' | tail -1)"

    confirm "Delete these caches?" || { log_info "nothing removed"; return 0; }

    for t in "${targets[@]}"; do
        case "$t" in
            /var/cache/pacman/pkg)
                # Let pacman prune its own cache rather than rm -rf'ing it.
                has paccache && sudo paccache -r || sudo pacman -Sc --noconfirm
                ;;
            *) rm -rf -- "${t:?}" ;;
        esac
    done
    # No hardcoded machine id here — the original pinned one specific journal.
    has journalctl && sudo journalctl --vacuum-time=1d
    has go && go clean -cache -modcache
    has npm && npm cache clean --force >/dev/null 2>&1
    log_ok "done"
}

# @describe Bundle every file an installed pacman package owns into a tarball,
#           for copying onto a machine that cannot reach the repositories.
# @usage    system_tarball_package <package> [output-dir]
# @example  system_tarball_package openssl ~/transfer
# @requires pacman tar
# @os       linux
system_tarball_package() {
    local pkg="${1:?usage: system_tarball_package <package> [output-dir]}"
    local outdir="${2:-${TMPDIR:-/tmp}}" staging f archive

    pacman -Qq "$pkg" >/dev/null 2>&1 || {
        log_error "system_tarball_package: '$pkg' is not installed"
        return 1
    }
    # A local variable, NOT TMPDIR — assigning that poisons mktemp for the rest
    # of the shell, which the original did.
    staging="$(tmp_dir "pkg-$pkg")" || return 1
    archive="$outdir/$pkg.tar.gz"

    while IFS= read -r f; do
        if [ -d "$f" ]; then
            mkdir -p "$staging/$f"
        else
            mkdir -p "$staging/$(dirname -- "$f")"
            cp -p -- "$f" "$staging/$f" 2>/dev/null
        fi
    done < <(pacman -Ql "$pkg" | cut -d' ' -f2-)

    tar -czf "$archive" -C "$staging" . && rm -rf -- "$staging"
    log_ok "tarball ready: $archive ($(path_size "$archive"))"
}

# @describe Ping-sweep the LAN and print the addresses of any Raspberry Pi,
#           matched on the Pi Foundation MAC prefixes.
# @usage    system_find_raspberry_pi [cidr] [interface]
# @example  system_find_raspberry_pi 192.0.2.0/24
# @requires nmap ip
# @os       linux
system_find_raspberry_pi() {
    local range="${1:-}" iface="${2:-${SHELLRC_WIFI_IFACE:-}}"

    if [ -z "$range" ]; then
        # Derive from the default route rather than assuming wlan0 exists.
        [ -n "$iface" ] || iface="$(ip route show default 2>/dev/null | awk '/default/{print $5; exit}')"
        [ -n "$iface" ] || { log_error "no default interface found — pass a CIDR"; return 1; }
        range="$(ip -o -f inet addr show "$iface" 2>/dev/null | awk '{print $4; exit}')"
        [ -n "$range" ] || { log_error "no IPv4 address on $iface — pass a CIDR"; return 1; }
    fi

    log_info "sweeping $range"
    # B8:27:EB and DC:A6:32 are both Raspberry Pi Foundation prefixes.
    sudo nmap -sn "$range" \
        | awk '/^Nmap scan report/{ip=$NF} /B8:27:EB|DC:A6:32|E4:5F:01/{print ip}'
}

# @describe Load the USB video kernel module, for a webcam that did not come up.
# @usage    system_enable_webcam
# @example  system_enable_webcam
# @requires modprobe
# @os       linux
system_enable_webcam() {
    sudo modprobe uvcvideo && log_ok "uvcvideo loaded"
}

# @describe Show a live preview from the webcam, to check it works.
# @usage    system_test_webcam [device]
# @example  system_test_webcam /dev/video0
# @requires mplayer
# @os       linux
# @see      system_enable_webcam
system_test_webcam() {
    local dev="${1:-/dev/video0}"
    [ -e "$dev" ] || { log_error "no such device: $dev (try system_enable_webcam)"; return 1; }
    mplayer tv:// -tv "driver=v4l2:device=$dev:width=1280:height=720:fps=30:outfmt=yuy2"
}

# ---- back-compat aliases -----------------------------------------------------
alias free_up_space=system_free_disk_space
alias tarball_pkg=system_tarball_package
alias find_pi=system_find_raspberry_pi
alias turn_on_cam=system_enable_webcam
alias test_webcam=system_test_webcam
