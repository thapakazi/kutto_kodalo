# @module desktop
# @summary Linux/X11 desktop odds and ends: i3 theming, ibus input method, and
#          the synchronised dark/light theme switcher.
#
# This module deliberately guards per function rather than with one top-level
# `require`: it covers three unrelated tool families (i3-style, ibus, X11
# automation) and a machine with i3 but no ibus should still get the i3 parts.
#
# ---------------------------------------------------------------------------
# A WORD ABOUT THE THEME SWITCHER
#
# desktop_theme_dark / desktop_theme_light drive other applications by faking
# keystrokes and mouse clicks with xdotool and wmctrl. That means:
#
#   * X11 only. It does nothing under Wayland, where synthetic input is blocked
#     by design.
#   * The Slack half clicks fixed pixel coordinates inside Slack's preferences
#     window. Those coordinates were measured on one screen, at one resolution,
#     against one Slack release, in 2020. They are almost certainly wrong now —
#     which means the clicks land on whatever else happens to be at 919x382.
#     They are exposed as DESKTOP_SLACK_* variables so you can re-measure with
#     desktop_probe_pointer instead of editing this file.
#
# It is kept because it still works on the author's i3 box and it is a lovely
# piece of duct tape (https://twitter.com/thapakazi_/status/1241208382268133376),
# but treat it as a fun experiment, not infrastructure. If you are on Wayland or
# a Mac, ignore this half of the file entirely.
# ---------------------------------------------------------------------------

# ------------------------------------------------------------------- ibus --

# Input method wiring for Devanagari and friends. Only exported when ibus is
# actually installed — otherwise these variables just break GTK apps' input.
if has ibus; then
    export GTK_IM_MODULE=ibus
    export QT_IM_MODULE=ibus
    export XMODIFIERS='@im=ibus'
fi

# --------------------------------------------------------------------- i3 --

# @describe List the themes i3-style knows about.
# @usage    desktop_i3_list_themes
# @example  desktop_i3_list_themes
# @requires i3-style
# @os       linux
desktop_i3_list_themes() {
    # Resolved through PATH. The original hardcoded
    # /usr/lib/node_modules/i3-style/lib/cli.js, which only existed on one box.
    require i3-style || return 1
    i3-style -l && log_info "apply one with: desktop_i3_set_theme <name>"
}

# @describe Apply an i3-style theme to ~/.i3/config and reload i3.
# @usage    desktop_i3_set_theme [theme]
# @example  desktop_i3_set_theme archlinux
# @requires i3-style
# @danger   Rewrites your i3 config in place. Keep it in version control.
# @os       linux
# @see      desktop_i3_list_themes
desktop_i3_set_theme() {
    require i3-style || return 1
    local theme="${1:-}" config="${I3_CONFIG:-$HOME/.i3/config}"
    if [ -z "$theme" ]; then
        desktop_i3_list_themes
        return 0
    fi
    [ -f "$config" ] || { log_error "no i3 config at $config"; return 1; }
    confirm "Rewrite $config with theme '$theme'?" || return 0
    i3-style "$theme" -o "$config" --reload
}

# @describe Install i3-style from npm.
# @usage    desktop_i3_install_style
# @example  desktop_i3_install_style
# @requires npm
# @os       linux
desktop_i3_install_style() {
    require npm || return 1
    sudo npm install -g i3-style
}

# ------------------------------------------------------------ window search --

# @describe Print the X window IDs whose class name matches a pattern.
# @usage    desktop_find_windows <class-name>
# @example  desktop_find_windows Alacritty
# @requires xdotool
# @os       linux
desktop_find_windows() {
    require xdotool || return 1
    xdotool search --classname "${1:-Brave-browser}"
}

# @describe Print window IDs by matching the window *title* instead of its
#           class. Slower, but it finds Electron apps that lie about their class.
# @usage    desktop_find_windows_by_title <pattern>
# @example  desktop_find_windows_by_title Slack
# @requires wmctrl
# @os       linux
desktop_find_windows_by_title() {
    require wmctrl || return 1
    wmctrl -l | grep -i -- "${1:-brave}" | cut -d' ' -f1 |
        while read -r id; do printf '%d\n' "$id"; done
}

# @describe Wait three seconds, then print where the mouse pointer is. Use it to
#           re-measure the Slack coordinates below when they drift.
# @usage    desktop_probe_pointer
# @example  desktop_probe_pointer
# @requires xdotool
# @os       linux
desktop_probe_pointer() {
    require xdotool || return 1
    log_info "move the pointer where you want it — reading in 3s"
    sleep 3
    xdotool getmouselocation --shell
}

# ---------------------------------------------------------- theme switching --

# Slack preferences click targets. Re-measure with desktop_probe_pointer.
DESKTOP_SLACK_MENU_XY="${DESKTOP_SLACK_MENU_XY:-531 222}"
DESKTOP_SLACK_DARK_XY="${DESKTOP_SLACK_DARK_XY:-919 382}"
DESKTOP_SLACK_LIGHT_XY="${DESKTOP_SLACK_LIGHT_XY:-901 233}"

# Private helpers. These were called `_terminal`, `_slack`, `_browser` and
# `_editor` — names so generic that any other module defining a helper about a
# terminal or an editor would have silently clobbered them.
_desktop_theme_terminal() {
    has xdotool && has buffer || return 0
    printf 'change_theme %s\n' "${1:-nord}" | buffer
    xdotool search --classname Alacritty windowactivate --sync \
        key --delay 400 ctrl+b c ctrl+shift+v ctrl+j ctrl+j ctrl+d
}

_desktop_theme_slack() {
    has xdotool && has wmctrl || return 0
    pgrep slack >/dev/null 2>&1 || return 0

    local coords="$DESKTOP_SLACK_DARK_XY" wid
    [ "${1:-dark}" = "light" ] && coords="$DESKTOP_SLACK_LIGHT_XY"
    wid=$(desktop_find_windows_by_title Slack | head -n 1)
    [ -n "$wid" ] || return 0

    # Unquoted on purpose: "531 222" must reach xdotool as two arguments.
    # shellcheck disable=SC2086
    xdotool windowactivate "$wid" key --delay 200 ctrl+0 ctrl+minus ctrl+comma &&
        xdotool mousemove $DESKTOP_SLACK_MENU_XY && xdotool click 1 &&
        xdotool mousemove $coords && xdotool click 1 &&
        xdotool windowactivate "$wid" key --delay 200 Escape
}

_desktop_theme_browser() {
    has xdotool && has wmctrl || return 0
    # Toggles the dark-reader extension; it has no absolute on/off shortcut.
    local wid
    for wid in $(desktop_find_windows_by_title brave); do
        xdotool windowactivate "$wid" key --delay 200 alt+shift+d
    done
}

_desktop_theme_editor() {
    has xdotool && has buffer || return 0
    local editor wid
    editor=$(shell_get_editor)
    printf '%s\n' "${1:-spacemacs-dark}" | buffer
    for wid in $(desktop_find_windows_by_title "$editor"); do
        xdotool key --window "$wid" super+F12 ctrl+y ctrl+j
    done
}

# @describe Put the editor, Slack, the browser and the terminal into dark mode
#           together.
# @usage    desktop_theme_dark
# @example  desktop_theme_dark
# @requires xdotool wmctrl
# @os       linux
# @see      desktop_theme_light desktop_theme_switch
desktop_theme_dark() {
    require xdotool wmctrl || return 1
    _desktop_theme_editor "spacemacs-dark"
    _desktop_theme_slack "dark"
    _desktop_theme_browser
    _desktop_theme_terminal "nord"
}

# @describe The same, in the other direction.
# @usage    desktop_theme_light
# @example  desktop_theme_light
# @requires xdotool wmctrl
# @os       linux
# @see      desktop_theme_dark desktop_theme_switch
desktop_theme_light() {
    require xdotool wmctrl || return 1
    _desktop_theme_editor "spacemacs-light"
    _desktop_theme_slack "light"
    _desktop_theme_browser
    _desktop_theme_terminal "bright"
}

# @describe Switch every application to the named theme. Anything other than
#           "light" or "bright" means dark.
# @usage    desktop_theme_switch [dark|light]
# @example  desktop_theme_switch light
# @requires xdotool wmctrl
# @os       linux
desktop_theme_switch() {
    # The original ended with `... && exit 0`, which closed the terminal it was
    # typed into whenever switching to the light theme succeeded.
    case "${1:-dark}" in
        light | bright | white) desktop_theme_light ;;
        *)                      desktop_theme_dark ;;
    esac
}

alias rc.d='systemctl'
