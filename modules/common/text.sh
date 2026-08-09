# @module text
# @summary Text and string plumbing: base64, splitting, binary dumps, JSON
#          pretty printing, QR codes, and .env file handling.
#
# Tool-specific functions live inside `require` blocks so a missing tool removes
# only those functions. Definitions stay unindented for the doc generator.

# ------------------------------------------------------------------ base64 ----

# @describe Base64-encode arguments, or stdin when called with none. Always one
#           line, no wrapping, on both BSD and GNU base64.
# @usage    text_encode_base64 [text]...
# @example  text_encode_base64 'hello world'
# @example  cat id_rsa.pub | text_encode_base64
# @os       any
# @see      text_decode_base64
text_encode_base64() {
    if [ $# -gt 0 ]; then
        printf '%s' "$*" | b64_encode
    else
        b64_encode
    fi
    printf '\n'
}

# @describe Base64-decode arguments, or stdin when called with none.
# @usage    text_decode_base64 [encoded]...
# @example  text_decode_base64 aGVsbG8gd29ybGQ=
# @example  clip_paste | text_decode_base64
# @os       any
# @see      text_encode_base64
text_decode_base64() {
    if [ $# -gt 0 ]; then
        printf '%s\n' "$*" | b64_decode
    else
        b64_decode
    fi
}

# --------------------------------------------------------------- splitting ----

# @describe Turn space-separated words into a JSON array of strings, ready to
#           paste into a config file.
# @usage    text_split_to_json_array <word>...
# @example  text_split_to_json_array alpha beta gamma
# @os       any
text_split_to_json_array() {
    [ $# -gt 0 ] || { log_error "usage: text_split_to_json_array <word>..."; return 1; }
    printf '%s\n' "$*" | sed 's/ /","/g' | awk '{print "[\"" $0 "\"]"}'
}

# @describe Split comma-separated values onto one line each.
# @usage    text_split_lines <csv>
# @example  text_split_lines aaa,bbb,ccc
# @example  text_split_lines a,b,c | xargs -I{} echo "item {}"
# @os       any
text_split_lines() {
    [ $# -gt 0 ] || { log_error "usage: text_split_lines <comma,separated,values>"; return 1; }
    printf '%s\n' "$*" | tr ',' '\n'
}

# --------------------------------------------------------------- binary ------

# @describe Print the 8-bit binary representation of every character in the
#           given text, one character per line.
# @usage    text_show_binary <text>...
# @example  text_show_binary hi
# @os       any
# @see      text_show_binary_inline
text_show_binary() {
    local char code
    [ $# -gt 0 ] || { log_error "usage: text_show_binary <text>..."; return 1; }
    # `|| [ -n "$char" ]` catches the last character: fold emits no trailing
    # newline, so a plain `read` loop silently dropped it.
    printf '%s' "$*" | fold -w1 | while IFS= read -r char || [ -n "$char" ]; do
        code=$( { LC_CTYPE=C printf '%d' "'$char"; } 2>/dev/null ) || continue
        printf '%s: %s\n' "$char" "$(_text_bits "$code")"
    done
}

# @describe Print the binary for some text as a single space-separated line,
#           followed by the original text.
# @usage    text_show_binary_inline <text>...
# @example  text_show_binary_inline hi
# @os       any
# @see      text_show_binary
text_show_binary_inline() {
    local bits
    [ $# -gt 0 ] || { log_error "usage: text_show_binary_inline <text>..."; return 1; }
    bits=$(text_show_binary "$@" | awk '{printf "%s%s", sep, $2; sep = " "}') || return 1
    printf '%s  %s\n' "$bits" "$*"
}

# Convert a decimal number to zero-padded 8-bit binary without needing bc.
_text_bits() {
    local n="$1" out=""
    while [ "$n" -gt 0 ]; do
        out="$((n % 2))$out"
        n=$((n / 2))
    done
    [ -n "$out" ] || out=0
    while [ "${#out}" -lt 8 ]; do out="0$out"; done
    printf '%s' "$out"
}

# ------------------------------------------------------------------- json -----

# @describe Pretty print JSON from a file or stdin. Uses jq when available and
#           falls back to python3's json.tool.
# @usage    text_pretty_json [file]
# @example  text_pretty_json package.json
# @example  curl -s https://api.github.com | text_pretty_json
# @requires jq|python3
# @os       any
text_pretty_json() {
    local file="$1"
    if has jq; then
        if [ -n "$file" ]; then jq . "$file"; else jq .; fi
    elif has python3; then
        if [ -n "$file" ]; then python3 -m json.tool "$file"; else python3 -m json.tool; fi
    else
        log_error "text_pretty_json: need jq or python3"
    fi
}

# ------------------------------------------------------------- environment ----

# @describe Grep the environment case-insensitively. With no argument it prints
#           the whole environment.
# @usage    text_grep_env [pattern]
# @example  text_grep_env proxy
# @os       any
text_grep_env() {
    if [ -n "$1" ]; then
        env | grep -i -- "$1"
    else
        env
    fi
}

# @describe Export every variable defined in a dotenv file. Handles values that
#           contain spaces, '=', '#' or quotes — the old `export $(sed ... |
#           xargs)` mangled all of those.
# @usage    text_load_env_file [file]
# @example  text_load_env_file
# @example  text_load_env_file .env.production
# @os       any
# @see      text_unload_env_file
text_load_env_file() {
    local _ef_file="${1:-.env}" _ef_line
    [ -r "$_ef_file" ] || { log_error "text_load_env_file: cannot read $_ef_file"; return 1; }
    while IFS= read -r _ef_line || [ -n "$_ef_line" ]; do
        _text_env_split "$_ef_line" || continue
        export "$_TEXT_ENV_KEY=$_TEXT_ENV_VALUE"
    done < "$_ef_file"
    unset _TEXT_ENV_KEY _TEXT_ENV_VALUE
}

# @describe Unset every variable named in a dotenv file.
# @usage    text_unload_env_file [file]
# @example  text_unload_env_file .env.production
# @os       any
# @see      text_load_env_file
text_unload_env_file() {
    local _ef_file="${1:-.env}" _ef_line
    [ -r "$_ef_file" ] || { log_error "text_unload_env_file: cannot read $_ef_file"; return 1; }
    while IFS= read -r _ef_line || [ -n "$_ef_line" ]; do
        _text_env_split "$_ef_line" || continue
        unset "$_TEXT_ENV_KEY"
    done < "$_ef_file"
    unset _TEXT_ENV_KEY _TEXT_ENV_VALUE
}

# Parse one dotenv line into _TEXT_ENV_KEY / _TEXT_ENV_VALUE. Returns non-zero
# for blank lines, comments, and anything that is not a valid assignment.
_text_env_split() {
    local line="$1" key value

    while [ "${line#[[:space:]]}" != "$line" ]; do line="${line#[[:space:]]}"; done
    case "$line" in
        '' | '#'*) return 1 ;;
        *=*) : ;;
        *) return 1 ;;
    esac

    line="${line#export }"
    key="${line%%=*}"
    value="${line#*=}"

    while [ "${key%[[:space:]]}" != "$key" ]; do key="${key%[[:space:]]}"; done
    case "$key" in
        '' | [0-9]* | *[!A-Za-z0-9_]*) log_warn "skipping invalid key: $key"; return 1 ;;
    esac

    case "$value" in
        \"*\") value="${value#\"}"; value="${value%\"}" ;;
        \'*\') value="${value#\'}"; value="${value%\'}" ;;
    esac

    _TEXT_ENV_KEY="$key"
    _TEXT_ENV_VALUE="$value"
    return 0
}

# ---------------------------------------------------------------- passwords ---

# @describe Generate a random password of the given length. Prints it by
#           default; with --copy it goes to the clipboard and is never echoed.
# @usage    text_random_password [length] [--copy]
# @example  text_random_password
# @example  text_random_password 32 --copy
# @os       any
text_random_password() {
    local length=16 copy=0 arg password
    for arg in "$@"; do
        case "$arg" in
            -c | --copy) copy=1 ;;
            '' | *[!0-9]*) log_error "usage: text_random_password [length] [--copy]"; return 1 ;;
            *) length="$arg" ;;
        esac
    done
    [ "$length" -gt 0 ] 2>/dev/null || { log_error "text_random_password: length must be positive"; return 1; }

    # The old class '_A-Z-a-z-0-9+-~!@#$%^&*()_+=-' hid three malformed ranges
    # (Z-a, 9+, +-~) that quietly pulled in punctuation nobody asked for.
    password=$(LC_ALL=C tr -dc 'A-Za-z0-9_!@#$%^&*()+=~-' < /dev/urandom | head -c "$length")
    [ -n "$password" ] || { log_error "text_random_password: could not read /dev/urandom"; return 1; }

    if [ "$copy" -eq 1 ]; then
        printf '%s' "$password" | clip_copy && log_ok "Copied a $length character password to the clipboard"
    else
        printf '%s\n' "$password"
    fi
    unset password
}

# ---------------------------------------------------------------- clipboard ---

# @describe Copy text to the clipboard and announce it with a talking cow.
#           Degrades to cowsay, then to a plain echo.
# @usage    text_copy_and_announce <text>...
# @example  text_copy_and_announce "deploy finished"
# @requires xcowsay|cowsay
# @os       any
text_copy_and_announce() {
    [ $# -gt 0 ] || { log_error "usage: text_copy_and_announce <text>..."; return 1; }
    printf '%s\n' "$*" | clip_copy || return 1
    if   has xcowsay; then xcowsay "$*"
    elif has cowsay;  then cowsay "$*"
    else printf '%s\n' "$*"
    fi
}

# ------------------------------------------------------------------ qrcode ----

if require qrencode; then

# @describe Render text as a QR code directly in the terminal.
# @usage    text_make_qrcode <text>...
# @example  text_make_qrcode 'WIFI:S:guest;T:WPA;P:hunter2;;'
# @requires qrencode
# @os       any
text_make_qrcode() {
    [ $# -gt 0 ] || { log_error "usage: text_make_qrcode <text>..."; return 1; }
    qrencode -t ansiutf8 -- "$*"
}

fi   # require qrencode

# --------------------------------------------------------------------- 2fa ----

if require 2fa fzf; then

# @describe Pick a 2FA account with fzf and copy its current code to the
#           clipboard.
# @usage    text_copy_2fa_code
# @example  text_copy_2fa_code
# @requires 2fa fzf
# @os       any
text_copy_2fa_code() {
    local account
    account=$(2fa -list | awk 'NF {print $1}' \
        | fzf --prompt="2FA account > " --height=12 --layout=reverse) || return 1
    [ -n "$account" ] || return 1
    2fa -clip "$account" >/dev/null || return 1
    log_ok "Copied the 2FA code for '$account' to the clipboard"
}

fi   # require 2fa fzf

# ------------------------------------------------------------ back-compat ----
# `buffer` and `buffercopy` are now thin aliases onto the lib primitives — the
# old buffer() function duplicated clip_copy exactly. Note that some Linux
# distributions ship a real buffer(1); the alias shadows it there.

alias buffer='clip_copy'
alias buffercopy='clip_copy_file'
alias buffer_with_cow='text_copy_and_announce'
alias base64_d='text_decode_base64'
alias randpassd='text_random_password'
alias randpass='text_random_password --copy'
alias split_string_like_js='text_split_to_json_array'
alias split_strings_to_new_line='text_split_lines'
alias get_binary='text_show_binary'
alias get_binary_one_line='text_show_binary_inline'
alias jcat='text_pretty_json'
alias envgrep='text_grep_env'
alias source_envfile='text_load_env_file'
alias unset_envfile='text_unload_env_file'
alias txt_2_qrcode='text_make_qrcode'
alias 2fa-fzf='text_copy_2fa_code'
