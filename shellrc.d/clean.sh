# --- Internal Helpers ---
_mc_get_size() {
    local path=$1
    if [[ -e "$path" ]]; then
        # Reliable size parsing for Zsh (index 1) and Bash (index 0)
        local du_output=($(du -sh "$path" 2>/dev/null))
        if [ -n "$ZSH_VERSION" ]; then echo "${du_output[1]}"; else echo "${du_output[0]}"; fi
    else
        echo "0B"
    fi
}

_mc_report_del() {
    local path=$1
    if [[ -e "$path" ]]; then
        local size=$(_mc_get_size "$path")
        local display_path="${path#$HOME/}"
        printf "  \033[0;90m[-] Removing %-40s (%s)...\033[0m\n" "$display_path" "$size"
        rm -rf "$path" 2>/dev/null
    fi
}

_mc_confirm() {
    local prompt=$1
    if [ -n "$ZSH_VERSION" ]; then
        read -q "REPLY?$(echo -e "\033[1;36m$prompt\033[0m [y/N]: ")"
    else
        read -p "$(echo -e "\033[1;36m$prompt\033[0m [y/N]: ")" -n 1 -r
    fi
    echo ""
    [[ "$REPLY" =~ ^[Yy]$ ]]
}

# --- mc-plan: The Estimator ---
mc-plan() {
    echo -e "\033[1m🔍 Potential Savings Audit\033[0m"
    echo "------------------------------------------------------------"
    
    local paths=(
        "$HOME/.cache/huggingface/hub"
        "$HOME/.cache/huggingface/xet"
        "$HOME/Library/Caches/com.electron.ollama.ShipIt"
        "$HOME/Library/Caches/com.anthropic.claudefordesktop.ShipIt"
        "$HOME/Library/Caches/com.herotools.openwispr.ShipIt"
        "$HOME/Library/Caches/com.hnc.Discord.ShipIt"
        "$HOME/Library/Caches/ollama"
        "$HOME/Library/Caches/com.apple.python"
        "$HOME/Library/Caches/goimports"
        "$HOME/.bun/install/cache"
        "$HOME/Library/Caches/org.swift.swiftpm"
        "$HOME/Library/Caches/ms-playwright"
        "$HOME/Library/Caches/com.duckduckgo.macos.browser"
        "$HOME/Library/Caches/Firefox"
        "$HOME/Library/Caches/com.raycast.macos"
        "$HOME/Library/Caches/ru.keepcoder.Telegram/org.sparkle-project.Sparkle"
    )

    for p in "${paths[@]}"; do
        if [[ -e "$p" ]]; then
            local p_short="${p#$HOME/}"
            printf "  %-50s \033[1;33m%7s\033[0m\n" "$p_short" "$(_mc_get_size "$p")"
        fi
    done

    # Package Managers & VMs
    command -v brew &>/dev/null && printf "  %-50s \033[1;33m%7s\033[0m\n" "Homebrew Cache" "$(_mc_get_size "$(brew --cache)")"

    if command -v docker &>/dev/null; then
        local d_size=$(docker system df --format "{{.Size}}" 2>/dev/null | head -n 1)
        [[ -n "$d_size" ]] && printf "  %-50s \033[1;33m%7s\033[0m\n" "Docker Artifacts" "$d_size"
    fi
    echo "------------------------------------------------------------"
}

# --- Category Functions ---

mc-ai() {
    echo "🧹 Scrubbing AI caches..."
    _mc_report_del "$HOME/.cache/huggingface/xet"
    _mc_report_del "$HOME/Library/Caches/com.electron.ollama.ShipIt"
    _mc_report_del "$HOME/Library/Caches/com.anthropic.claudefordesktop.ShipIt"
    _mc_report_del "$HOME/Library/Caches/ollama"

    if command -v hf &>/dev/null; then
        echo -e "  \033[1;33m[!] Hugging Face CLI requires manual selection:\033[0m"
        hf cache scan -vvv
        hf cache delete --disable-tui
    fi
    echo -e "  ✅ AI Phase Complete\n"
}

mc-dev() {
    echo "🧹 Clearing Dev artifacts..."
    
    # UV, Pip, Go, NPM CLI Cleanup
    [[ -n "$(command -v uv)" ]] && echo "  [-] uv cache clean" && uv cache clean &>/dev/null
    [[ -n "$(command -v pip)" ]] && echo "  [-] pip cache purge" && pip cache purge &>/dev/null
    [[ -n "$(command -v go)" ]] && echo "  [-] go clean caches" && go clean -cache -testcache -modcache &>/dev/null
    [[ -n "$(command -v npm)" ]] && echo "  [-] npm cache clean" && npm cache clean --force &>/dev/null

    # Folders
    _mc_report_del "$HOME/Library/Caches/com.apple.python"
    _mc_report_del "$HOME/Library/Caches/Jedi"
    _mc_report_del "$HOME/Library/Caches/goimports"
    _mc_report_del "$HOME/.bun/install/cache"
    _mc_report_del "$HOME/Library/Caches/org.swift.swiftpm"
    echo -e "  ✅ Dev Phase Complete\n"
}

mc-app() {
    echo "🧹 Wiping App & Browser junk..."
    
    if command -v brew &>/dev/null; then
        echo "  [-] Running brew cleanup..."
        brew cleanup &>/dev/null
        _mc_report_del "$(brew --cache)"
    fi

    _mc_report_del "$HOME/Library/Caches/ms-playwright"
    _mc_report_del "$HOME/Library/Caches/com.duckduckgo.macos.browser"
    _mc_report_del "$HOME/Library/Caches/Firefox"
    _mc_report_del "$HOME/Library/Caches/com.raycast.macos"
    _mc_report_del "$HOME/Library/Caches/com.herotools.openwispr.ShipIt"
    _mc_report_del "$HOME/Library/Caches/com.hnc.Discord.ShipIt"
    _mc_report_del "$HOME/Library/Caches/ru.keepcoder.Telegram/org.sparkle-project.Sparkle"
    _mc_report_del "$HOME/Library/Caches/open-whispr-updater"
    _mc_report_del "$HOME/Library/Caches/Google\ Earth"
    
    echo -e "  ✅ App Phase Complete\n"
}

mc-vm() {
    echo "⚠️  Pruning Virtualization..."
    if command -v docker &>/dev/null; then
        docker system df
        docker system prune --all --volumes -f
    fi
    [[ -n "$(command -v limactl)" ]] && echo "  [-] limactl prune" && limactl prune -f &>/dev/null
    echo -e "  ✅ Virtualization Pruned\n"
}

# --- Master Command ---
mac-clean() {
    mc-plan
    _mc_confirm "Start cleaning based on these estimates?" || return
    
    _mc_confirm "Clean AI (HF, Ollama, Claude)?" && mc-ai
    _mc_confirm "Clean Dev (Go, Python, Bun, NPM, UV)?" && mc-dev
    _mc_confirm "Clean Apps (Brew, DDG, Raycast, Discord)?" && mc-app
    _mc_confirm "Prune Virtualization (Docker, Lima)?" && mc-vm
    
    echo -e "\033[1;32m✨ Lets goo !!!\033[0m"
}
