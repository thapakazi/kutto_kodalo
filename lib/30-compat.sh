# @module compat
# @summary Cross-platform primitives. Modules MUST use these instead of calling
#          xclip, pbcopy, xdg-open, `sed -i`, `readlink -f`, or `base64 -w`
#          directly — those all differ between macOS (BSD) and Linux (GNU).

# ---------------------------------------------------------------- clipboard --

# @describe Copy stdin to the system clipboard. Works with pbcopy (macOS),
#           wl-copy (Wayland), or xclip/xsel (X11).
# @usage    <command> | clip_copy
# @example  echo "hello" | clip_copy
# @requires pbcopy|wl-copy|xclip|xsel
# @os       any
clip_copy() {
    if   has pbcopy;  then pbcopy
    elif has wl-copy; then wl-copy
    elif has xclip;   then xclip -selection clipboard
    elif has xsel;    then xsel --clipboard --input
    else log_error "No clipboard tool found (install pbcopy, wl-copy, xclip, or xsel)"
    fi
}

# @describe Print the current system clipboard contents to stdout.
# @usage    clip_paste
# @example  clip_paste | wc -l
# @requires pbpaste|wl-paste|xclip|xsel
# @os       any
clip_paste() {
    if   has pbpaste;  then pbpaste
    elif has wl-paste; then wl-paste
    elif has xclip;    then xclip -selection clipboard -o
    elif has xsel;     then xsel --clipboard --output
    else log_error "No clipboard tool found (install pbpaste, wl-paste, xclip, or xsel)"
    fi
}

# @describe Copy the contents of a file to the clipboard.
# @usage    clip_copy_file <file>
# @example  clip_copy_file ~/.ssh/id_ed25519.pub
# @os       any
clip_copy_file() {
    [ -f "$1" ] || { log_error "clip_copy_file: no such file: $1"; return 1; }
    clip_copy < "$1"
}

# --------------------------------------------------------------------- open --

# @describe Open a file, directory, or URL in the desktop default application.
# @usage    os_open <path-or-url>
# @example  os_open https://github.com
# @requires open|xdg-open
# @os       any
os_open() {
    if   has open;     then open "$@"
    elif has xdg-open; then xdg-open "$@" >/dev/null 2>&1
    else log_error "No opener found (need open or xdg-open)"
    fi
}

# ------------------------------------------------------------ gnu userland ---

# @describe Print the name of a GNU-compatible sed. Prefers gsed on macOS where
#           the system sed is BSD and rejects GNU syntax.
# @usage    gnu_sed
# @example  "$(gnu_sed)" -E 's/a+/b/' file
# @requires gsed|sed
# @os       any
gnu_sed() {
    if has gsed; then echo gsed; else echo sed; fi
}

# @describe Edit a file in place portably. BSD sed requires an argument to -i,
#           GNU sed refuses one — this handles both.
# @usage    sed_inplace <sed-expression> <file>...
# @example  sed_inplace 's/foo/bar/g' config.toml
# @os       any
sed_inplace() {
    local expr="$1"; shift
    if has gsed; then
        gsed -i "$expr" "$@"
    elif sed --version >/dev/null 2>&1; then
        sed -i "$expr" "$@"          # GNU sed
    else
        sed -i '' "$expr" "$@"       # BSD sed
    fi
}

# @describe Resolve a path to its canonical absolute form, following symlinks.
#           Replacement for `readlink -f`, which older macOS lacks.
# @usage    path_resolve <path>
# @example  path_resolve ~/.shellrc
# @os       any
path_resolve() {
    local target="$1" dir base
    [ -n "$target" ] || return 1
    if has realpath; then realpath "$target" 2>/dev/null && return 0; fi
    while [ -L "$target" ]; do
        local link
        link=$(command ls -ld -- "$target" | sed -e 's/.* -> //')
        case "$link" in
            /*) target="$link" ;;
            *)  target="$(dirname -- "$target")/$link" ;;
        esac
    done
    dir=$(dirname -- "$target")
    base=$(basename -- "$target")
    printf '%s/%s\n' "$(cd -- "$dir" 2>/dev/null && pwd -P)" "$base"
}

# @describe Base64-encode stdin as a single line with no wrapping. `base64 -w0`
#           is GNU-only and errors on macOS.
# @usage    <command> | b64_encode
# @example  printf 'secret' | b64_encode
# @os       any
b64_encode() {
    if base64 --version >/dev/null 2>&1; then
        base64 -w 0            # GNU
    else
        base64 | tr -d '\n'    # BSD wraps at 76 cols by default
    fi
}

# @describe Base64-decode stdin. Handles the GNU (-d) / BSD (-D) flag split.
# @usage    <command> | b64_decode
# @example  echo aGk= | b64_decode
# @os       any
b64_decode() {
    if base64 --version >/dev/null 2>&1; then
        base64 -d
    else
        base64 -D 2>/dev/null || base64 -d
    fi
}

# ------------------------------------------------------------- temp & sizes --

# @describe Create a secure temporary file and print its path. Always prefer this
#           over hardcoded /tmp/name paths, which are predictable and hijackable.
# @usage    tmp_file [name-hint]
# @example  f=$(tmp_file policy); echo '{}' > "$f"
# @os       any
tmp_file() {
    mktemp "${TMPDIR:-/tmp}/shellrc-${1:-tmp}.XXXXXXXX"
}

# @describe Create a secure temporary directory and print its path.
# @usage    tmp_dir [name-hint]
# @example  d=$(tmp_dir certs); cd "$d"
# @os       any
tmp_dir() {
    mktemp -d "${TMPDIR:-/tmp}/shellrc-${1:-tmp}.XXXXXXXX"
}

# @describe Print a human-readable size for a file or directory, or 0B if absent.
# @usage    path_size <path>
# @example  path_size ~/Library/Caches
# @os       any
path_size() {
    [ -e "$1" ] || { echo "0B"; return 0; }
    du -sh -- "$1" 2>/dev/null | awk '{print $1}'
}

# @describe Print an ISO-8601 timestamp suitable for filenames (no colons).
# @usage    timestamp
# @example  mv old "backup-$(timestamp)"
# @os       any
timestamp() { date +%Y%m%d-%H%M%S; }
