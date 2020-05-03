# super hakish them switcher
# built with <3 using the
#   xdotool, wmctrl,
#   buffer (which uses xclip internally)
#   browser: dark-reader extension
#   editor: my theme switch function on emacs
#   slack: I like to use it on 90% zoom level
#
# why: I build this... I am get tired of changing between dark and white mode on all the application
#  tweet: https://twitter.com/thapakazi_/status/1241208382268133376
#
# my stack:
#   editor   : emacs
#   terminal : alacritty
#   browser  : brave
#   and slack
#
# Notes: Apollogies I created this super hackish script just for me :),
#        modify if you want, and don't ask for help :P

_terminal(){
    theme=${1:-'nord'}
    echo change_theme $theme |buffer 
    xdotool search --classname Alacritty windowactivate  --sync key --delay 400 ctrl+b c ctrl+shift+v ctrl+j ctrl+j ctrl+d
}

search_windows(){
    application_name=${1:-'Brave-browser'}
    xdotool search  --classname $application_name
}

# deps: wmctrl
# why: its better than xdotool search :)
search_windows_wmctrl(){
    application_name=${1:-'brave'}
    wmctrl -l \
        | grep -i $application_name \
        |cut -d' ' -f1 \
        |xargs -I id printf "%d\n" id
}

_slack(){
    theme=${1:-'dark'}
    coordinates='919 382'  # dark theme coordinates
    test $theme == "light" && coordinates='901 233'
    themes_coordinates='531 222'
    WID=$(search_windows_wmctrl 'Slack')
    pgrep slack &> /dev/null && \
        xdotool windowactivate $WID key --delay 200 ctrl+0 ctrl+minus ctrl+comma && \
        xdotool mousemove `echo $themes_coordinates` && \
        xdotool click 1 && \
        xdotool mousemove `echo $coordinates` && \
        xdotool click 1 && \
        xdotool windowactivate $WID key --delay 200 Escape
}

_browser(){
    # assuming you have dark-reader plugin installed
    for WID in $(search_windows_wmctrl "brave"|xargs); do
        xdotool windowactivate $WID key --delay 200 alt+shift+d
    done
}

_editor(){
    theme=${1:-'spacemacs-dark'}
    WID=$(search_windows_wmctrl "Emacs")
    echo $theme | buffer
    xdotool key --window $WID super+F12 ctrl+y ctrl+j

}

_x_helper_get_window_info(){
    sleep 3s; xdotool getmouselocation --shell
}

theme_switch_dark(){
    _editor
    _slack
    _browser
    _terminal
}

theme_switch_white(){
    _editor "spacemacs-light"
    _slack "light"
    _browser
    _terminal "bright"
    
}

theme_switch(){
    test "$1" == "bright" && theme_switch_white && exit 0
    theme_switch_dark

}
