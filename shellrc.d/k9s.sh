
k9s_config_dir=~/.config/k9s/
k9s_themes_init(){
    source ~/.shellrc.d/os.sh
    mkdir $k9s_config_dir -p
    set -xv
    if_mac && ln -s ~/.config/k9s/ ~/Library/Application\ Support/
    rm -rf /tmp/k9s  && git clone https://github.com/derailed/k9s.git /tmp/k9s --depth=1
    mv -v /tmp/k9s/skins $k9s_config_dir && rm -rf /tmp/k9s
}

k9s_change_theme(){
    ln -fs $k9s_config_dir/skins/${1:-'solarized_dark'}.yml $k9s_config_dir/skin.yml
}
