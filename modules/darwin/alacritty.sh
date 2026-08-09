# @module alacritty
# @summary Alacritty theme management: fetch the upstream theme pool and rewrite
#          the `import` line in alacritty.toml, optionally picking day or night.
#
# Theme pool: https://github.com/alacritty/alacritty-theme
# The config is expected to import a theme like:
#     import = ["~/.config/alacritty/themes/themes/nord.toml"]

ALACRITTY_CONFIG_DIR="${ALACRITTY_CONFIG_DIR:-$HOME/.config/alacritty}"
ALACRITTY_THEMES_DIR="${ALACRITTY_THEMES_DIR:-$ALACRITTY_CONFIG_DIR/themes}"
ALACRITTY_THEMES_REPO="${ALACRITTY_THEMES_REPO:-https://github.com/alacritty/alacritty-theme}"
ALACRITTY_DAY_THEME="${ALACRITTY_DAY_THEME:-noctis-lux}"
ALACRITTY_NIGHT_THEME="${ALACRITTY_NIGHT_THEME:-night_owl}"

# Hour (00-23) at and after which `alacritty_is_night` reports night.
ALACRITTY_NIGHT_HOUR="${ALACRITTY_NIGHT_HOUR:-17}"

# ------------------------------------------------------------------ private --

# Resolve the real config file, following symlinks. Lazy on purpose: resolving
# at source time would fork a process on every shell startup.
_alacritty_config_file() {
    local file="$ALACRITTY_CONFIG_DIR/alacritty.toml"
    if [ ! -e "$file" ]; then
        log_error "alacritty: no config at $file"
        return 1
    fi
    path_resolve "$file"
}

_alacritty_themes_exist() {
    [ -d "$ALACRITTY_THEMES_DIR/themes" ]
}

# ------------------------------------------------------------------- public --

# @describe True when the local clock has passed the night threshold
#           (ALACRITTY_NIGHT_HOUR, default 17).
# @usage    alacritty_is_night
# @example  alacritty_is_night && echo "dark theme time"
# @os       darwin
alacritty_is_night() {
    local hour="" threshold="$ALACRITTY_NIGHT_HOUR"
    hour="$(date +%H)"
    # Force base 10: a leading zero would otherwise be read as octal.
    case "$hour" in '' | *[!0-9]*) return 1 ;; esac
    case "$threshold" in '' | *[!0-9]*) return 1 ;; esac
    [ "$((10#$hour))" -ge "$((10#$threshold))" ]
}

# @describe List the themes available in the local theme pool.
# @usage    alacritty_list_themes
# @example  alacritty_list_themes
# @os       darwin
# @see      alacritty_fetch_themes
alacritty_list_themes() {
    if ! _alacritty_themes_exist; then
        log_warn "No themes yet. Run: alacritty_fetch_themes"
        return 1
    fi
    printf '%s=== available themes ===%s\n' "$C_BOLD" "$C_RESET"
    find "$ALACRITTY_THEMES_DIR/themes" -maxdepth 1 -name '*.toml' -exec basename {} .toml \; \
        | sort | paste - - - | column -t
}

# @describe Point alacritty.toml at a theme from the local pool. With no
#           argument it picks ALACRITTY_DAY_THEME or ALACRITTY_NIGHT_THEME
#           depending on the time of day.
# @usage    alacritty_set_theme [theme-name]
# @example  alacritty_set_theme nord
# @example  alacritty_set_theme            # time-of-day default
# @requires gsed|sed
# @os       darwin
# @see      alacritty_list_themes
alacritty_set_theme() {
    local theme="$1" config=""

    if [ -z "$theme" ]; then
        if alacritty_is_night; then
            theme="$ALACRITTY_NIGHT_THEME"
        else
            theme="$ALACRITTY_DAY_THEME"
        fi
    fi

    case "$theme" in
        *[!A-Za-z0-9._-]* | "")
            log_error "alacritty: invalid theme name: $theme"
            return 1
            ;;
    esac

    if ! _alacritty_themes_exist; then
        log_error "alacritty: no theme pool at $ALACRITTY_THEMES_DIR (run alacritty_fetch_themes)"
        return 1
    fi

    if [ ! -f "$ALACRITTY_THEMES_DIR/themes/$theme.toml" ]; then
        log_error "alacritty: no such theme: $theme"
        return 1
    fi

    config="$(_alacritty_config_file)" || return 1

    sed_inplace "s|/themes/themes/[^./]*\\.toml|/themes/themes/${theme}.toml|g" "$config" || return 1
    log_ok "alacritty theme -> $theme"
}

# @describe Clone the upstream theme pool if missing, pull the latest themes,
#           then list what is available.
# @usage    alacritty_fetch_themes
# @example  alacritty_fetch_themes
# @requires git
# @os       darwin
alacritty_fetch_themes() {
    has git || { log_error "alacritty: git is required to fetch themes"; return 1; }

    if ! _alacritty_themes_exist; then
        mkdir -p "$ALACRITTY_CONFIG_DIR" || return 1
        git clone "$ALACRITTY_THEMES_REPO" "$ALACRITTY_THEMES_DIR" || return 1
    fi

    alacritty_update_themes
    alacritty_list_themes
}

# @describe Pull the latest themes into the local pool.
# @usage    alacritty_update_themes
# @example  alacritty_update_themes
# @requires git
# @os       darwin
alacritty_update_themes() {
    has git || { log_error "alacritty: git is required to update themes"; return 1; }
    _alacritty_themes_exist || { log_error "alacritty: no theme pool at $ALACRITTY_THEMES_DIR"; return 1; }
    # Subshell so the caller's working directory is never changed.
    ( cd "$ALACRITTY_THEMES_DIR" && git pull --ff-only )
}

# @describe Delete the local theme pool.
# @usage    alacritty_remove_themes
# @example  alacritty_remove_themes
# @os       darwin
# @danger   Recursively deletes $ALACRITTY_THEMES_DIR, including local edits.
alacritty_remove_themes() {
    [ -d "$ALACRITTY_THEMES_DIR" ] || return 0
    confirm "Delete the alacritty theme pool at $ALACRITTY_THEMES_DIR?" || return 0
    rm -rf -- "$ALACRITTY_THEMES_DIR"
    log_ok "Removed $ALACRITTY_THEMES_DIR"
}

# @describe Fetch the theme pool and apply the time-of-day theme in one go.
# @usage    alacritty_setup
# @example  alacritty_setup
# @requires git
# @os       darwin
# @see      alacritty_fetch_themes alacritty_set_theme
alacritty_setup() {
    alacritty_fetch_themes || return 1
    alacritty_set_theme
}

# ------------------------------------------------------------------ aliases --

alias change_theme='alacritty_set_theme'
alias list_themes='alacritty_list_themes'
alias fetch_themes='alacritty_fetch_themes'
