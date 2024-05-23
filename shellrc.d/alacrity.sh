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
alacritty_upstream_themes=https://github.com/alacritty/alacritty-theme

# time agnostic
change_theme(){
    default_theme=${1:-noctis-lux}
    is_night && default_theme=${1:-night_owl}
    sed  "s|~/.config/alacritty/themes/themes/[^.]*\.toml|~/.config/alacritty/themes/themes/${default_theme}.toml|g" ~/.config/alacritty/alacritty.toml -i
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
        cd $alacritty_conf_dir
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
        ls -1 $alacritty_themes_dir/themes/*.toml|sed -r 's/(.*)\/(.*).toml/    \2/g' | paste - - - | column -t
    else
        echo "=== sorry no themes, use fn: fetch_themes ==="
    fi
}

# warning, destructive
remove_themes(){
    rm -irf $alacritty_themes_dir
}

alacritty_init_conf(){
    echo '
    import = [
        "~/.config/alacritty/themes/themes/dracula.toml"
    ]'  >  $alacritty_conf_dir/alacritty.toml
}

alacritty_do_it_all(){
   alacritty_init_conf
   fetch_themes
   change_theme
}
