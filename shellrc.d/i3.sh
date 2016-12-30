# get i3-sytle first
get_i3-style(){
    sudo npm install -g i3-style
}

# change theme
change_theme(){
    i3-style ${1:-archlinux} -o ~/.i3/config --reload
}

#beautify i3_allthethings
i3_allthethings(){
    get_i3-style
    change_theme
}
