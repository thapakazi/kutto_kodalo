# one liner to adjust the alacritty theme
# this func actually seds in themes
# assumption: your theme resides inside a block like:
#   #+begin_theme
#   ...  << this gets populated from different color_theme.yml files
#   #+end_theme
#
# Usage:
#    $ alacritty_init_conf
#    $ change_theme nord
#
# Credits to theme pool: https://github.com/eendroroy/alacritty-theme
alacritty_conf_dir=~/.config/alacritty
alacritty_themes_dir=~/.config/alacritty/themes
alacritty_upstream_themes=https://github.com/thapakazi/alacritty-theme

# time agnostic 
change_theme(){
    default_theme=${1:-bright}.yaml
    is_night && default_theme=${1:-nord}.yaml
    sed -e  "/#+begin_theme/,/#+end_theme/c\#+begin_theme\n $(sed -e 's/$/ \\/' ~/.config/alacritty/themes/$default_theme) \n#+end_theme" $alacritty_conf_dir/alacritty.yml -i
}

is_night(){
    time=$(date +%H)
    [ "$time" -gt 17 ] && return 0 || return 1
}

# lol, test function to see if day or night :D
greetings(){
    is_night && echo "goodnight $(whoami)" && return 0
    echo "good-day $(whoami)"
}

check_if_themes_exists(){
    [ -d $alacritty_themes_dir ] && return $?
}

fetch_themes(){
    if ! check_if_themes_exists; then
        git clone $alacritty_upstream_themes $alacritty_themes_dir
    fi
    update_themes
    list_themes
}

update_themes(){
    cd $alacritty_themes_dir && git pull
}
list_themes(){
    if check_if_themes_exists; then
        echo "=== your available themes ==="
        echo "-----------------------------"
        ls -1 $alacritty_themes_dir/*.yaml|sed -r 's/(.*)\/(.*).yaml/    \2/g'
    else
        echo "=== sorry no themes, use fn: fetch_themes ==="
    fi
}

# warning, destructive
remove_themes(){
    rm -irf $alacritty_themes_dir
}

alacritty_init_conf(){
    echo 'fetching vanilla conf from: https://gist.github.com/thapakazi/c19cc42be668a4fc66e63b1423c150d7.pibb'
    curl -sL https://git.io/fhNYu >  $alacritty_conf_dir/alacritty.yml
}
