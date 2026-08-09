# @module docker-disk
# @summary Mount an external disk under Docker's data root and restore the
#          iptables rules Docker needs afterwards. Linux only — this uses
#          mount -t UUID=, iptables-restore, and systemd.
#
# Originally a single hardcoded "docker_hack" with one machine's disk UUID
# baked in. The UUID, mount point, and rules file are now settings you point at
# your own hardware; nothing is assumed.

require docker || return 0

# ---------------------------------------------------------------- settings --

# Filesystem UUID of the disk to mount. Intentionally empty by default: the
# functions below refuse to run until you set it, e.g. in modules/local/.
#   lsblk -o NAME,UUID,SIZE,FSTYPE,MOUNTPOINT
SHELLRC_DOCKER_DISK_UUID="${SHELLRC_DOCKER_DISK_UUID:-}"

# Where that disk gets mounted (usually bind-mounted at Docker's data root).
SHELLRC_DOCKER_DISK_MOUNT="${SHELLRC_DOCKER_DISK_MOUNT:-/mnt/sandisk}"

# iptables ruleset replayed after mounting, in iptables-save format.
SHELLRC_DOCKER_IPTABLES_RULES="${SHELLRC_DOCKER_IPTABLES_RULES:-$HOME/.docker/iptables.config}"

# ------------------------------------------------------------ private bits --

# Complain, usefully, when no disk UUID has been configured.
_docker_disk_uuid_or_die() {
    if [ -n "$SHELLRC_DOCKER_DISK_UUID" ]; then
        printf '%s\n' "$SHELLRC_DOCKER_DISK_UUID"
        return 0
    fi
    log_error "SHELLRC_DOCKER_DISK_UUID is not set — refusing to guess a disk."
    log_info  "Find the UUID with:  lsblk -o NAME,UUID,SIZE,FSTYPE,MOUNTPOINT"
    log_info  "Then set it in modules/local/:"
    log_info  "    SHELLRC_DOCKER_DISK_UUID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    return 1
}

# ----------------------------------------------------------------- mounting --

# @describe Mount the configured data disk by UUID, replay Docker's saved
#           iptables rules, and restart the docker service.
# @usage    docker_mount_data_disk [uuid]
# @example  docker_mount_data_disk
# @example  docker_mount_data_disk 8a741529-d1f6-4c90-9f90-9dc96cddf9fc
# @requires docker mount
# @os       linux
# @see      docker_unmount_data_disk
docker_mount_data_disk() {
    local uuid="${1:-}" mount_point="$SHELLRC_DOCKER_DISK_MOUNT"
    [ -n "$uuid" ] || uuid="$(_docker_disk_uuid_or_die)" || return 1

    if ! has mount; then
        log_error "docker_mount_data_disk: mount(8) not found"
        return 1
    fi
    if [ ! -d "$mount_point" ]; then
        log_error "docker_mount_data_disk: mount point does not exist: $mount_point"
        log_info  "Create it first:  sudo mkdir -p \"$mount_point\""
        return 1
    fi

    if has mountpoint && mountpoint -q "$mount_point"; then
        log_info "already mounted: $mount_point"
    else
        sudo mount "UUID=$uuid" "$mount_point" || {
            log_error "docker_mount_data_disk: mounting UUID=$uuid failed"
            return 1
        }
        log_ok "mounted UUID=$uuid at $mount_point"
    fi

    if [ -s "$SHELLRC_DOCKER_IPTABLES_RULES" ]; then
        if has iptables-restore; then
            sudo iptables-restore < "$SHELLRC_DOCKER_IPTABLES_RULES" \
                && log_ok "restored iptables rules from $SHELLRC_DOCKER_IPTABLES_RULES"
        else
            log_warn "iptables-restore not found; skipping rule restore"
        fi
    else
        log_warn "no saved rules at $SHELLRC_DOCKER_IPTABLES_RULES; skipping"
        log_info "Save them once with:  sudo iptables-save > \"$SHELLRC_DOCKER_IPTABLES_RULES\""
    fi

    if has systemctl; then
        sudo systemctl restart docker && log_ok "docker restarted"
    else
        log_warn "systemctl not found; restart docker yourself"
    fi
}

# @describe Stop docker and unmount the configured data disk.
# @usage    docker_unmount_data_disk
# @example  docker_unmount_data_disk
# @requires docker umount
# @os       linux
# @danger   Stops the docker daemon, killing every running container. Prompts first.
# @see      docker_mount_data_disk
docker_unmount_data_disk() {
    local mount_point="$SHELLRC_DOCKER_DISK_MOUNT"

    if has mountpoint && ! mountpoint -q "$mount_point"; then
        log_info "not mounted: $mount_point"
        return 0
    fi

    confirm "Stop docker (killing all containers) and unmount $mount_point?" || return 0

    if has systemctl; then
        sudo systemctl stop docker && log_ok "docker stopped"
    else
        log_warn "systemctl not found; stop docker yourself before unmounting"
    fi

    sudo umount "$mount_point" || {
        log_error "docker_unmount_data_disk: umount $mount_point failed (still busy?)"
        return 1
    }
    log_ok "unmounted $mount_point"
}

# ------------------------------------------------------ back-compat aliases --

alias docker_hack='docker_mount_data_disk'
alias docker_hack_cleanup='docker_unmount_data_disk'
