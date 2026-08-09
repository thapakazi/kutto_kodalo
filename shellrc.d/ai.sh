hf_cleanup(){
    rm -rf ~/.cache/huggingface/xet/
}

# hf clean
hf_cleanup(){
    hf cache scan -vvv
    hf cache delete --disable-tui
}

# uv cleanup
uv_cache_clean(){
    du -sh `uv cache dir`
    uv cache clean
}

#pip
pip_cache_purge(){
    pip cache info
    pip cache purge 
}


npm_cache_clean(){
    npm cache clean --force
}

bun_cache_clean(){
    rm -rf ~/.bun/install/cache/ 
}

docker_system_prune(){
    docker system df
    docker system prune --all
}

lima_cleanup(){
    limactl prune
}


brew_cleanup(){
    brew cleanup -n
    #brew cleanup 
    #brew cleanup  -s
    rm -rf $(brew --cache)
}

purge_pure_junk(){
    rm -rf ~/Library/Caches/ms-playwright
    rm -rf ~/Library/Caches/Google\ Earth/  
    rm -rf ~/Library/Caches/com.electron.ollama.ShipIt
    rm -rf ~/Library/Caches/com.duckduckgo.macos.browser
    rm -rf ~/Library/Caches/Firefox
    rm -rf ~/Library/Caches/com.anthropic.claudefordesktop.ShipIt
    rm -rf ~/Library/Caches/com.herotools.openwispr.ShipIt 
    rm -rf ~/Library/Caches/com.hnc.Discord.ShipIt
    rm -rf ~/Library/Caches/ru.keepcoder.Telegram/org.sparkle-project.Sparkle
    rm -rf ~/Library/Caches/org.swift.swiftpm 
    rm -rf ~/Library/Caches/open-whispr-updater
    rm -rf ~/Library/Caches/com.apple.python 
    rm -rf ~/Library/Caches/com.raycast.macos
    rm -rf ~/Library/Caches/goimports
    rm -rf ~/Library/Caches/ollama
}


claude(){
    export IS_DEMO=1
    /opt/homebrew/bin/claude
}
