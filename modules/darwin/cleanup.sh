# @module cleanup
# @summary macOS disk reclamation: estimate first, then purge caches by category
#          behind an explicit confirmation. Merges the old `clean.sh` estimator
#          with the unguarded cache removals that used to live in `ai.sh`.
#
# Every destructive entry point prompts via `confirm` and reports the size it is
# about to reclaim. Nothing here runs at source time.

# Extra confirmation before Docker volumes are destroyed (they hold real data).
CLEANUP_DOCKER_VOLUMES="${CLEANUP_DOCKER_VOLUMES:-0}"

# ------------------------------------------------------------------ private --

# Print the cache paths for a category, one per line. Paths may contain spaces,
# so callers must read them with `while IFS= read -r`.
_cleanup_paths() {
    case "$1" in
        ai)
            printf '%s\n' \
                "$HOME/.cache/huggingface/xet" \
                "$HOME/Library/Caches/com.electron.ollama.ShipIt" \
                "$HOME/Library/Caches/com.anthropic.claudefordesktop.ShipIt" \
                "$HOME/Library/Caches/ollama"
            ;;
        dev)
            printf '%s\n' \
                "$HOME/Library/Caches/com.apple.python" \
                "$HOME/Library/Caches/Jedi" \
                "$HOME/Library/Caches/goimports" \
                "$HOME/Library/Caches/org.swift.swiftpm" \
                "$HOME/.bun/install/cache"
            ;;
        apps)
            printf '%s\n' \
                "$HOME/Library/Caches/ms-playwright" \
                "$HOME/Library/Caches/com.duckduckgo.macos.browser" \
                "$HOME/Library/Caches/Firefox" \
                "$HOME/Library/Caches/com.raycast.macos" \
                "$HOME/Library/Caches/com.herotools.openwispr.ShipIt" \
                "$HOME/Library/Caches/com.hnc.Discord.ShipIt" \
                "$HOME/Library/Caches/open-whispr-updater" \
                "$HOME/Library/Caches/ru.keepcoder.Telegram/org.sparkle-project.Sparkle" \
                "$HOME/Library/Caches/Google Earth"
            ;;
        all)
            printf '%s\n' "$HOME/.cache/huggingface/hub"
            _cleanup_paths ai
            _cleanup_paths dev
            _cleanup_paths apps
            _cleanup_claude_vm_path
            ;;
    esac
}

# The Claude Desktop VM bundle. A directory, several GB, and expensive to
# re-download — it never gets removed without its own confirmation.
_cleanup_claude_vm_path() {
    printf '%s\n' "$HOME/Library/Application Support/Claude/vm_bundles/claudevm.bundle"
}

# Refuse to delete anything that is not clearly a cache path under $HOME.
# NOTE: never name a local `path` — in zsh that is tied to $PATH and assigning
# it empties the command search path for the whole function scope.
_cleanup_path_is_safe() {
    local target="$1"
    [ -n "$target" ] || return 1
    case "$target" in
        "/" | "$HOME" | "$HOME/") return 1 ;;
        "$HOME"/*) return 0 ;;
        *) return 1 ;;
    esac
}

# Report and remove one path. Silent when the path does not exist.
_cleanup_rm() {
    local target="$1" size=""
    if ! _cleanup_path_is_safe "$target"; then
        log_warn "cleanup: refusing to remove unsafe path: $target"
        return 1
    fi
    [ -e "$target" ] || return 0
    size="$(path_size "$target")"
    printf '  %s[-] %-46s %7s%s\n' "$C_DIM" "${target#"$HOME"/}" "$size" "$C_RESET"
    rm -rf -- "$target"
}

# Remove every path in a category.
_cleanup_rm_category() {
    local target=""
    _cleanup_paths "$1" | while IFS= read -r target; do
        _cleanup_rm "$target"
    done
}

# One row of the estimate table.
_cleanup_report_row() {
    printf '  %-52s %s%7s%s\n' "$1" "$C_YELLOW" "$2" "$C_RESET"
}

# Hugging Face purge without its own prompt — callers confirm first.
_cleanup_hf_prune() {
    _cleanup_rm "$HOME/.cache/huggingface/xet"
    has hf || return 0
    log_info "Hugging Face hub requires manual selection:"
    hf cache scan -vvv
    hf cache delete --disable-tui
}

# ------------------------------------------------------------------- public --

# @describe Audit reclaimable disk space without deleting anything. Lists every
#           cache path this module knows about, plus the Homebrew cache and
#           Docker's reported artefact size.
# @usage    cleanup_estimate
# @example  cleanup_estimate
# @requires du
# @os       darwin
# @see      cleanup_all
cleanup_estimate() {
    local target="" docker_size=""
    printf '%sPotential savings audit%s\n' "$C_BOLD" "$C_RESET"
    printf -- '--------------------------------------------------------------\n'

    _cleanup_paths all | while IFS= read -r target; do
        [ -e "$target" ] || continue
        _cleanup_report_row "${target#"$HOME"/}" "$(path_size "$target")"
    done

    if has brew; then
        _cleanup_report_row "Homebrew cache" "$(path_size "$(brew --cache)")"
    fi

    if has docker; then
        docker_size="$(docker system df --format '{{.Size}}' 2>/dev/null | head -n 1)"
        [ -n "$docker_size" ] && _cleanup_report_row "Docker artefacts" "$docker_size"
    fi

    printf -- '--------------------------------------------------------------\n'
}

# @describe Purge Hugging Face caches. Removes the xet chunk cache outright and
#           hands the model hub to `hf cache delete`, which prompts for which
#           repos to drop.
# @usage    cleanup_purge_hf
# @example  cleanup_purge_hf
# @requires hf
# @os       darwin
# @danger   Deletes downloaded model data. Re-downloading is slow and metered.
cleanup_purge_hf() {
    confirm "Purge Hugging Face caches?" || return 0
    _cleanup_hf_prune
}

# @describe Purge AI tooling caches: Hugging Face, Ollama, Claude Desktop's
#           updater cache, and optionally the multi-gigabyte Claude VM bundle.
# @usage    cleanup_purge_ai
# @example  cleanup_purge_ai
# @os       darwin
# @danger   Deletes model and VM data. The Claude VM bundle is several GB and is
#           gated behind its own second confirmation.
# @see      cleanup_estimate cleanup_purge_hf
cleanup_purge_ai() {
    local vm_bundle="" vm_size=""

    confirm "Clean AI caches (Hugging Face, Ollama, Claude)?" || return 0
    log_info "Scrubbing AI caches..."
    _cleanup_rm_category ai
    _cleanup_hf_prune

    # Was guarded with -f on a directory in clean.sh, so it never ran. It runs
    # now, which makes the extra confirmation mandatory.
    vm_bundle="$(_cleanup_claude_vm_path)"
    if [ -e "$vm_bundle" ]; then
        vm_size="$(path_size "$vm_bundle")"
        if confirm "Remove the Claude VM bundle ($vm_size)? It must be re-downloaded."; then
            _cleanup_rm "$vm_bundle"
        fi
    fi

    log_ok "AI phase complete"
}

# @describe Purge developer toolchain caches: uv, pip, go, npm, bun, swiftpm,
#           Jedi, goimports, and the Python bytecode cache.
# @usage    cleanup_purge_dev
# @example  cleanup_purge_dev
# @os       darwin
# @danger   Empties package manager caches. Next build re-downloads everything.
cleanup_purge_dev() {
    confirm "Clean dev caches (uv, pip, go, npm, bun, swiftpm)?" || return 0
    log_info "Clearing dev artefacts..."

    if has uv;  then printf '  [-] uv cache clean\n';  uv cache clean >/dev/null 2>&1; fi
    if has pip; then printf '  [-] pip cache purge\n'; pip cache purge >/dev/null 2>&1; fi
    if has go;  then printf '  [-] go clean caches\n'; go clean -cache -testcache -modcache >/dev/null 2>&1; fi
    if has npm; then printf '  [-] npm cache clean\n'; npm cache clean --force >/dev/null 2>&1; fi

    _cleanup_rm_category dev
    log_ok "Dev phase complete"
}

# @describe Purge application and browser caches, plus the Homebrew download
#           cache after running `brew cleanup`.
# @usage    cleanup_purge_apps
# @example  cleanup_purge_apps
# @os       darwin
# @danger   Deletes cached application data and every downloaded Homebrew bottle.
cleanup_purge_apps() {
    local brew_cache=""

    confirm "Clean app caches (Homebrew, browsers, Raycast, Discord)?" || return 0
    log_info "Wiping app and browser junk..."

    if has brew; then
        printf '  [-] brew cleanup\n'
        brew cleanup >/dev/null 2>&1
        brew_cache="$(brew --cache 2>/dev/null)"
        [ -n "$brew_cache" ] && _cleanup_rm "$brew_cache"
    fi

    _cleanup_rm_category apps
    log_ok "App phase complete"
}

# @describe Prune virtualization artefacts: unused Docker images, containers,
#           networks and build cache, then Lima instance leftovers.
# @usage    cleanup_purge_vm
# @example  CLEANUP_DOCKER_VOLUMES=1 cleanup_purge_vm
# @requires docker|limactl
# @os       darwin
# @danger   Removes every unused Docker image and container. Docker volumes are
#           only touched after a separate confirmation — they hold real data.
cleanup_purge_vm() {
    confirm "Prune virtualization (Docker, Lima)?" || return 0
    log_info "Pruning virtualization..."

    if has docker; then
        docker system df
        if [ "$CLEANUP_DOCKER_VOLUMES" = "1" ] && confirm "Also delete unused Docker VOLUMES (data loss)?"; then
            docker system prune --all --volumes -f
        else
            docker system prune --all -f
        fi
    fi

    if has limactl; then
        printf '  [-] limactl prune\n'
        limactl prune -f >/dev/null 2>&1
    fi

    log_ok "Virtualization pruned"
}

# @describe Run the full reclamation: print the estimate, then walk each
#           category. Every category asks before it touches anything, so any
#           prompt can be declined without aborting the rest.
# @usage    cleanup_all
# @example  cleanup_all
# @os       darwin
# @danger   Chains every destructive function in this module.
# @see      cleanup_estimate cleanup_purge_ai cleanup_purge_dev cleanup_purge_apps cleanup_purge_vm
cleanup_all() {
    cleanup_estimate
    confirm "Start cleaning based on these estimates?" || return 0

    cleanup_purge_ai
    cleanup_purge_dev
    cleanup_purge_apps
    cleanup_purge_vm

    log_ok "Reclamation finished."
}

# ------------------------------------------------------------------ aliases --

alias mc-plan='cleanup_estimate'
alias mc-ai='cleanup_purge_ai'
alias mc-dev='cleanup_purge_dev'
alias mc-app='cleanup_purge_apps'
alias mc-vm='cleanup_purge_vm'
alias mac-clean='cleanup_all'
