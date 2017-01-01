# get i3-sytle first
get_i3-style(){
    sudo npm install -g i3-style
}

#list all the themes
i3_list_themes(){
    # /usr/bin/i3-sytle -l
    # hardcoding sucks... :(
    /usr/lib/node_modules/i3-style/lib/cli.js -l
    [ $? -eq 0 ] && \
        echo "use function $BGreen i3_change_theme $Color_Off $BPurple::theme_name:: $Color_Off"
}

# change theme
i3_change_theme(){
    [ $# -eq 0 ] && i3_list_themes
    i3-style ${1:-archlinux} -o ~/.i3/config --reload
}

#beautify i3_allthethings
i3_allthethings(){
    get_i3-style
    change_theme
}
