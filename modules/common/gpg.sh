# @module gpg
# @summary Back up and restore a GPG keypair as a single password-encrypted zip.
#
# SECURITY REWRITE. The original shellrc.d/gpg.sh had a quoted tilde in
# BACKUP_DIR="~/.backups/gpg_backups_$DATE_STAMP", so the tilde never expanded.
# `gpg_backup` therefore created a literal directory named `~` in whatever
# directory you happened to be standing in and wrote secret.asc — your exported
# PRIVATE KEY — into it with default permissions. Encrypting the result was an
# optional y/n prompt, so answering "n" (or hitting Ctrl-C) left an unencrypted
# private key sitting in a stray ./~/ folder, world-readable, forever.
#
# This version never lets a plaintext key touch a path that outlives the
# function: the export happens under umask 077 inside mktemp -d, the encrypted
# archive is the only artefact, and a trap removes the working directory even on
# failure or interrupt.

require gpg || return 0

# Where finished (encrypted) archives are written. Override in modules/local/.
GPG_BACKUP_DIR="${GPG_BACKUP_DIR:-$HOME/.backups}"

# Prompt for a secret key id, echoing the listing to stderr so that command
# substitution captures only the id. (The original echoed the whole listing to
# stdout, so the caller's "$key_id" contained the entire key table.)
_gpg_pick_secret_key() {
    local selected=""
    {
        printf '%s\n' "--- Available GPG secret keys ---"
        gpg --list-secret-keys --keyid-format LONG
        printf '%s\n' "---------------------------------"
    } >&2

    if [ -n "$ZSH_VERSION" ]; then
        read "selected?Enter the GPG key ID to back up: " || return 1
    else
        read -r -p "Enter the GPG key ID to back up: " selected || return 1
    fi

    [ -n "$selected" ] || { log_error "No key ID entered."; return 1; }
    gpg --list-secret-keys "$selected" >/dev/null 2>&1 ||
        { log_error "Key ID '$selected' not found."; return 1; }

    printf '%s\n' "$selected"
}

# @describe List the secret keys GPG knows about, with long key IDs.
# @usage    gpg_list_keys
# @example  gpg_list_keys
# @requires gpg
# @os       any
gpg_list_keys() {
    gpg --list-secret-keys --keyid-format LONG
}

# @describe Export a keypair (public, secret, ownertrust) straight into a
#           password-encrypted zip under $GPG_BACKUP_DIR. Encryption is not
#           optional: the plaintext export lives only inside a 0700 mktemp
#           directory that a trap deletes on every exit path.
# @usage    gpg_backup [key-id]
# @example  gpg_backup
# @example  gpg_backup 0xDEADBEEFCAFE1234
# @requires gpg zip
# @danger   Writes your private key. The archive is only as strong as the zip
#           password you type — use a long one, and store the archive offline.
# @os       any
# @see      gpg_restore
gpg_backup() {
    require zip || {
        log_error "zip is required — refusing to write an unencrypted private key."
        return 1
    }

    local key_id date_stamp archive
    if [ -n "$1" ]; then
        key_id="$1"
        gpg --list-secret-keys "$key_id" >/dev/null 2>&1 ||
            { log_error "Key ID '$key_id' not found."; return 1; }
    else
        key_id=$(_gpg_pick_secret_key) || return 1
    fi

    # Computed here, not at load time. The original assigned DATE_STAMP when the
    # file was sourced, so a long-lived shell stamped every backup with the date
    # it started rather than the date it ran.
    date_stamp=$(date +%F)
    archive="$GPG_BACKUP_DIR/gpg_backup_${key_id}_${date_stamp}.zip"

    mkdir -p "$GPG_BACKUP_DIR" || return 1
    chmod 700 "$GPG_BACKUP_DIR" 2>/dev/null

    log_info "Backing up key: $key_id"
    log_warn "You will be asked for a zip password. It protects your private key — make it long."

    # Subshell so umask and the trap are scoped and cannot leak into the user's
    # interactive shell. `exit` here leaves the subshell only; it is never the
    # sourced-file `exit` that the conventions forbid.
    (
        umask 077
        work=$(tmp_dir gpg-backup) || exit 1
        trap 'rm -rf "$work"' EXIT INT TERM HUP

        gpg --armor --export "$key_id"             > "$work/public.asc" || exit 1
        gpg --armor --export-secret-keys "$key_id" > "$work/secret.asc" || exit 1
        gpg --export-ownertrust                    > "$work/trust.txt"  || exit 1

        [ -s "$work/secret.asc" ] || { printf 'secret key export was empty\n' >&2; exit 1; }

        rm -f "$archive"
        zip -e -j "$archive" "$work/public.asc" "$work/secret.asc" "$work/trust.txt" || exit 1
    ) || { log_error "Backup failed — nothing was left on disk."; return 1; }

    chmod 600 "$archive" 2>/dev/null
    log_ok "Encrypted backup written to $archive"
}

# @describe Import a keypair from an archive produced by gpg_backup, or from a
#           directory holding public.asc / secret.asc / trust.txt.
# @usage    gpg_restore <archive.zip|directory>
# @example  gpg_restore ~/.backups/gpg_backup_0xDEADBEEF_2026-08-09.zip
# @requires gpg unzip
# @danger   Imports a private key into your keyring and overwrites ownertrust.
# @os       any
# @see      gpg_backup
gpg_restore() {
    local target="$1"
    [ -n "$target" ] || { log_error "Usage: gpg_restore <archive.zip|directory>"; return 1; }
    [ -e "$target" ] || { log_error "No such path: $target"; return 1; }

    # Directory input: import in place, nothing temporary to clean up. The
    # original still ran `[ -d "$temp_extract" ] && rm -rf "$temp_extract"` on
    # this path, dereferencing a variable it had never set.
    if [ -d "$target" ]; then
        _gpg_import_from "$target"
        return $?
    fi

    require unzip || return 1
    confirm "Import a private key from $target into your keyring?" || return 0

    (
        umask 077
        work=$(tmp_dir gpg-restore) || exit 1
        trap 'rm -rf "$work"' EXIT INT TERM HUP

        unzip -q "$target" -d "$work" || exit 1
        _gpg_import_from "$work" || exit 1
    ) || { log_error "Restore failed."; return 1; }

    log_ok "Restore complete."
}

_gpg_import_from() {
    local dir="$1" ok=0
    if [ ! -f "$dir/public.asc" ] && [ ! -f "$dir/secret.asc" ]; then
        log_error "No public.asc or secret.asc in $dir — is this a gpg_backup archive?"
        return 1
    fi
    [ -f "$dir/public.asc" ] && { gpg --import "$dir/public.asc" || ok=1; }
    [ -f "$dir/secret.asc" ] && { gpg --import "$dir/secret.asc" || ok=1; }
    [ -f "$dir/trust.txt"  ] && { gpg --import-ownertrust "$dir/trust.txt" || ok=1; }
    return "$ok"
}
