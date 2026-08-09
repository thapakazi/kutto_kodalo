# @module calendar
# @summary Drive every gcalcli profile at once — work calendar and personal
#          calendar in a single command.
#
# gcalcli keeps one config folder per Google account. Put each account's folder
# under $GCALCLI_CONFIG_DIR (default ~/.gcalcli) and these helpers fan a command
# out across all of them.
#
# credits: https://github.com/insanum/gcalcli

require gcalcli || return 0

GCALCLI_CONFIG_DIR="${GCALCLI_CONFIG_DIR:-$HOME/.gcalcli}"

# @describe Run the same gcalcli command against every configured account.
#           Defaults to `agenda`.
# @usage    calendar_all [gcalcli-args...]
# @example  calendar_all
# @example  calendar_all calw
# @example  calendar_all quick "lunch with sam tomorrow 12pm"
# @requires gcalcli
# @os       any
calendar_all() {
    [ -d "$GCALCLI_CONFIG_DIR" ] ||
        { log_error "No gcalcli config dir at $GCALCLI_CONFIG_DIR"; return 1; }

    # The original wrote `action=${@:-agenda}`, which flattens every argument
    # into one unquoted string and then relies on word splitting to take it
    # apart again — so anything containing a space was silently mangled.
    [ $# -eq 0 ] && set -- agenda

    local profile found=0
    for profile in "$GCALCLI_CONFIG_DIR"/*/; do
        [ -d "$profile" ] || continue
        profile="${profile%/}"
        found=1
        log_info "── ${profile##*/}"
        gcalcli --config-folder "$profile" "$@"
    done

    [ "$found" -eq 1 ] ||
        { log_error "No account folders inside $GCALCLI_CONFIG_DIR"; return 1; }
}

# @describe Show today's agenda across every configured account.
# @usage    calendar_agenda
# @example  calendar_agenda
# @requires gcalcli
# @os       any
calendar_agenda() {
    calendar_all agenda "$@"
}

# @describe Show the current week across every configured account.
# @usage    calendar_week
# @example  calendar_week
# @requires gcalcli
# @os       any
calendar_week() {
    calendar_all calw "$@"
}

alias gcalcli_all='calendar_all'
