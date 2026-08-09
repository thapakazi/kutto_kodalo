# @module fun
# @summary Jokes, cows, reminders and other things that make a terminal feel
#          like home. Nothing here runs at load time.
#
# Folded in from the old fun.sh, rhoit/cowfortunes.sh, super_custom_stufffs.sh
# and nepali.sh. Two things changed on the way in:
#
#   * cowfortunes.sh called `cowfortune` at the bottom of the file, so every
#     single shell start forked `brew list --version` (~1s), plus ls, shuf and
#     fortune, before you could type. That was the largest startup cost in the
#     repo. The greeting is now opt-in: call fun_cowsay_fortune yourself, or add
#     it to modules/local/ if you want it on login.
#   * fun.sh defined a function literally called `uptime`, shadowing
#     /usr/bin/uptime for every script and alias that ever needed the real one.

# ------------------------------------------------------------------ helpers --

# Pick one line from stdin at random. Replaces `shuf -n 1`, which is GNU-only
# and absent from a stock macOS.
_fun_random_line() {
    awk -v seed="${RANDOM:-0}$$" '
        BEGIN { srand(seed) }
        { lines[NR] = $0 }
        END   { if (NR) print lines[int(rand() * NR) + 1] }'
}

# ------------------------------------------------------------------- jokes --

# @describe The uptime you deserve, not the uptime you have. Renamed from the
#           original `uptime`, which shadowed the real binary.
# @usage    fun_uptime
# @example  fun_uptime
# @os       any
fun_uptime() {
    printf '%s\n' "lol, YOU BEEN UP ALL NIGHT HIGH all season"
}

# @describe Print one memorable command per letter of the alphabet.
# @usage    fun_a_to_z
# @example  fun_a_to_z
# @os       any
fun_a_to_z() {
    cat <<'EOF'
a - awk      n - nc
b - bash     o - openssl
c - cat      p - ping
d - dig      q - quick_pg
e - emacs    r - rm
f - find     s - sed
g - git      t - tail
h - hostname u - unset
i - ip       v - vim
j - jq       w - watch
k - kubectl  x - xkill
l - less     y - yes
m - mtr      z - zip
EOF
}

# @describe Grep your ~/.emoji cheatsheet.
# @usage    fun_emoji <pattern>
# @example  fun_emoji shrug
# @os       any
fun_emoji() {
    [ -n "$1" ] || { log_error "usage: fun_emoji <pattern>"; return 1; }
    [ -f "$HOME/.emoji" ] || { log_error "no ~/.emoji cheatsheet found"; return 1; }
    grep -i -- "$1" "$HOME/.emoji"
}

# @describe Fill the terminal with static, like a television nobody is watching.
#           Runs until you press Ctrl-C.
# @usage    fun_old_tv
# @example  fun_old_tv
# @os       any
fun_old_tv() {
    local rows cols glyph
    rows="${LINES:-$(tput lines 2>/dev/null || echo 24)}"
    cols="${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}"
    log_info "static until Ctrl-C"
    while :; do
        # A case, not `cut -c`, because these glyphs are multibyte and cut
        # counts bytes on some systems and characters on others.
        case $(( RANDOM % 5 )) in
            0) glyph=' ' ;;
            1) glyph='█' ;;
            2) glyph='░' ;;
            3) glyph='▒' ;;
            *) glyph='▓' ;;
        esac
        printf '\033[%d;%df%s' \
            "$(( RANDOM % rows + 1 ))" \
            "$(( RANDOM % cols + 1 ))" \
            "$glyph"
    done
}

# @describe Re-run the previous command under sudo. Inspired by
#           https://twitter.com/kathyra_/status/1160810013113237504
# @usage    fun_sudo_last
# @example  fun_sudo_last
# @danger   Runs your last command as root. The original alias
#           `damn_it='sudo $(fc -ln -1)'` did this instantly, with no echo of
#           what it was about to run and no confirmation — so a typo'd or
#           half-remembered previous command went straight to root. This version
#           prints the command and waits for an explicit yes.
# @os       any
fun_sudo_last() {
    local last
    last=$(fc -ln -1 2>/dev/null | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    [ -n "$last" ] || { log_error "could not read the previous command"; return 1; }

    log_warn "About to run as root:"
    printf '    sudo %s\n' "$last" >&2
    confirm "Run it?" || { log_info "nothing was run"; return 0; }
    eval "sudo $last"
}

# ------------------------------------------------------------------- cows --

# @describe Print the name of a randomly chosen cowsay cowfile. Portable: asks
#           cowsay itself for the list instead of the original's
#           `brew list --version` + hardcoded Cellar path, which only worked on
#           an Intel Mac with Homebrew, inside a file that was written on Linux.
# @usage    fun_mascot
# @example  cowsay -f "$(fun_mascot)" moo
# @requires cowsay
# @os       any
fun_mascot() {
    has cowsay || { log_error "cowsay is not installed"; return 1; }
    local name
    name=$(cowsay -l 2>/dev/null | tail -n +2 | tr ' ' '\n' | awk 'NF' | _fun_random_line)
    printf '%s\n' "${name:-default}"
}

# @describe Print a random pair of cow eyes.
# @usage    fun_eye
# @example  cowsay -e "$(fun_eye)" moo
# @os       any
fun_eye() {
    local eyes='oo $$ zz -- ++ @@ uu ~~ .. xx ee •• ☆☆ ♥♥ »« øø'
    printf '%s' "$eyes" | tr ' ' '\n' | awk 'NF' | _fun_random_line
}

# @describe A random cow saying (or thinking) a random fortune. This used to run
#           on every shell start; now you have to ask for it.
# @usage    fun_cowsay_fortune
# @example  fun_cowsay_fortune
# @requires cowsay fortune
# @os       any
fun_cowsay_fortune() {
    has cowsay  || { log_error "cowsay is not installed";  return 1; }
    has fortune || { log_error "fortune is not installed"; return 1; }

    local speaker=cowsay
    if [ $(( RANDOM % 2 )) -eq 1 ] && has cowthink; then
        speaker=cowthink
    fi
    "$speaker" -f "$(fun_mascot)" -e "$(fun_eye)" "$(fortune -s)"
}

# @describe Put a message in a cow's mouth and hand it to the tweet_cow helper.
# @usage    fun_cow_tweet <message>...
# @example  fun_cow_tweet "moo means hello"
# @requires tweet_cow
# @os       any
fun_cow_tweet() {
    has tweet_cow || { log_error "tweet_cow is not installed"; return 1; }
    [ $# -gt 0 ] || { log_error "usage: fun_cow_tweet <message>"; return 1; }
    TWEET_MSG="$*" tweet_cow
}

# --------------------------------------------------------------- reminders --

# Pop up a desktop notification, falling back all the way down to a beep.
_fun_notify() {
    local title="$1" body="$2"
    if has xcowsay; then
        if [ -n "$FUN_XCOWSAY_IMAGE" ]; then
            xcowsay --cow-size=med -t 15 --image="$FUN_XCOWSAY_IMAGE" --think "$body"
        else
            xcowsay --cow-size=med -t 15 --think "$body"
        fi
    elif has notify-send; then
        notify-send "$title" "$body"
    elif has terminal-notifier; then
        terminal-notifier -title "$title" -message "$body"
    elif has osascript; then
        osascript -e "display notification \"$body\" with title \"$title\"" >/dev/null 2>&1
    else
        printf '\a\n*** %s: %s ***\n' "$title" "$body"
    fi
}

# @describe Nag yourself later. Sleeps in the background, then notifies. Renamed
#           from `remind`, which is a real binary on Debian and Arch.
# @usage    fun_remind in <duration> <message>...
# @example  fun_remind in 30m i need to start studying
# @example  fun_remind
# @os       any
fun_remind() {
    local when message
    # Grammar is `fun_remind in <duration> <message...>`; "in" is decoration.
    # The original read the duration as "$2" and the message as ${${@:3}:-...},
    # a zsh-only nested expansion that misuses $@.
    [ "$1" = "in" ] && shift
    when="${1:-5m}"
    [ $# -gt 0 ] && shift
    message="$*"
    [ -n "$message" ] || message="lets go eat :)"

    log_info "ok, will remind you in $when about: $message"
    { sleep "$when" && _fun_notify "reminder" "$message"; } &
}

# ------------------------------------------------------------------- media --

# @describe Play something with mplayer using an alternate video output driver.
# @usage    fun_mplayer_vo <driver> [mplayer-args...]
# @example  fun_mplayer_vo caca video.mkv
# @requires mplayer
# @os       any
fun_mplayer_vo() {
    has mplayer || { log_error "mplayer is not installed"; return 1; }
    mplayer -vo "$@"
}

# @describe Stream a video URL straight into mplayer without saving it.
# @usage    fun_mplayer_stream <url>
# @example  fun_mplayer_stream 'https://youtu.be/dQw4w9WgXcQ'
# @requires yt-dlp|youtube-dl mplayer
# @os       any
fun_mplayer_stream() {
    has mplayer || { log_error "mplayer is not installed"; return 1; }
    local fetcher
    if   has yt-dlp;     then fetcher=yt-dlp
    elif has youtube-dl; then fetcher=youtube-dl
    else log_error "need yt-dlp or youtube-dl"; return 1
    fi
    [ -n "$1" ] || { log_error "usage: fun_mplayer_stream <url>"; return 1; }
    "$fetcher" -q -o- "$1" | mplayer -af scaletempo -softvol -softvol-max 400 -cache 8192 -
}

# ------------------------------------------------------------ upside down --

# github.com/haude/upisdown — override the path in modules/local/ if yours lives
# somewhere else. The original hardcoded /home/thapakazi/github/...
FUN_UPISDOWN_BIN="${FUN_UPISDOWN_BIN:-$HOME/github/haude/upisdown}"

# @describe ˙uʍop ǝpısdn ʇxǝʇ ɹnoʎ uɹnʇ
# @usage    fun_flip <text>...
# @example  fun_flip hello world
# @os       any
fun_flip() {
    [ -x "$FUN_UPISDOWN_BIN/main.sh" ] ||
        { log_error "upisdown not found at $FUN_UPISDOWN_BIN (set FUN_UPISDOWN_BIN)"; return 1; }
    "$FUN_UPISDOWN_BIN/main.sh" "$@"
}

# @describe Flip text and put it on the clipboard. Uses clip_copy rather than
#           calling xclip directly, so it also works on macOS and Wayland.
# @usage    fun_flip_copy <text>...
# @example  fun_flip_copy hello world
# @os       any
fun_flip_copy() {
    fun_flip "$@" | clip_copy
}

# @describe Watch a tiny pac-man eat your prompt for a second.
# @usage    fun_pacman_anim
# @example  fun_pacman_anim
# @requires pamcan
# @os       any
fun_pacman_anim() {
    local bin="${FUN_PAMCAN_BIN:-$HOME/.go/bin/pamcan}"
    has pamcan && bin=pamcan
    [ -x "$bin" ] || [ "$bin" = pamcan ] ||
        { log_error "pamcan not found (set FUN_PAMCAN_BIN)"; return 1; }
    "$bin" && sleep 1 && clear
}

# ------------------------------------------------------------------ aliases --

alias damn_it='fun_sudo_last'
alias mplayer_ascii='fun_mplayer_vo aa -monitorpixelaspect 0.5'
alias mplayer_caca='fun_mplayer_vo caca'
alias mplayer_matrix='fun_mplayer_vo matrixview'

# नेपाली — harmless, and it makes people smile.
alias लस='ls'
alias छद='cd'
