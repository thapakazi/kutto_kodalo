#!/bin/bash

# depends on os.sh
source $SHELLRCD/os.sh 

# Configuration
DATE_STAMP=$(date +%F)
BACKUP_DIR="~/.backups/gpg_backups_$DATE_STAMP"

# Specific check for this script's requirements
bootstrap() {
    local missing=()
    command -v gpg &> /dev/null || missing+=("gnupg")
    command -v zip &> /dev/null || missing+=("zip")
    command -v unzip &> /dev/null || missing+=("unzip")

    if [ ${#missing[@]} -gt 0 ]; then
        install_deps "${missing[@]}"
    else
        echo "All requirements met."
    fi
}

get_pass_key_id() {
    echo "--- Available GPG Secret Keys ---"
    gpg --list-secret-keys --keyid-format LONG
    echo "---------------------------------"
    
    local selected_id
    printf "Enter the GPG Key ID to back up: "
    read selected_id

    if [[ -z "$selected_id" ]]; then
        echo "Error: No ID entered."
        return 1
    fi

    if ! gpg --list-secret-keys "$selected_id" &>/dev/null; then
        echo "Error: Key ID '$selected_id' not found."
        return 1
    fi

    echo "$selected_id"
}

gpg_backup() {
    bootstrap || return 1
    local key_id=$(get_pass_key_id)
    [ $? -ne 0 ] && return 1

    echo "Backing up key: $key_id"
    mkdir -p "$BACKUP_DIR"

    gpg --armor --export "$key_id" > "$BACKUP_DIR/public.asc"
    gpg --armor --export-secret-keys "$key_id" > "$BACKUP_DIR/secret.asc"
    gpg --export-ownertrust > "$BACKUP_DIR/trust.txt"

    read -p "Create encrypted zip? (y/n): " do_zip
    if [[ "$do_zip" =~ ^[Yy]$ ]]; then
        local zip_name="gpg_backup_$DATE_STAMP.zip"
        zip -erj "$zip_name" "$BACKUP_DIR" && rm -rf "$BACKUP_DIR"
        echo "Backup saved to $zip_name"
    fi
}

gpg_restore() {
    bootstrap || return 1
    local target=$1
    if [ -z "$target" ]; then
        echo "Usage: $0 restore [file.zip|directory]"
        return 1
    fi

    if [[ "$target" == *.zip ]]; then
        local temp_extract="temp_restore_$(date +%s)"
        unzip "$target" -d "$temp_extract"
        target="$temp_extract"
    fi

    gpg --import "$target/public.asc"
    gpg --import "$target/secret.asc"
    gpg --import-ownertrust "$target/trust.txt"

    [ -d "$temp_extract" ] && rm -rf "$temp_extract"
    echo "Restore complete."
}

# case "$1" in
#     backup)  gpg_backup ;;
#     restore) gpg_restore "$2" ;;
#     install) install_deps "${@:2}" ;; # Pass all args after 'install'
#     list)    gpg --list-secret-keys --keyid-format LONG ;;
#     *)       echo "Usage: $0 {backup|restore|list|install pkg1 pkg2}" ;;
# esac
