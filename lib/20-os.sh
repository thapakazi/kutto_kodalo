# @module os
# @summary Operating system and package manager detection.

# @describe Print the OS family as a lowercase token the loader uses for module
#           directories: darwin, linux, or unknown.
# @usage    os_name
# @example  [ "$(os_name)" = darwin ] && echo "on a mac"
# @os       any
os_name() {
    case "$(uname -s)" in
        Darwin) echo darwin ;;
        Linux)  echo linux ;;
        *)      echo unknown ;;
    esac
}

# @describe True when running on macOS.
# @usage    is_macos
# @example  is_macos && alias ls='ls -G'
# @os       any
is_macos() { [ "$(uname -s)" = "Darwin" ]; }

# @describe True when running on Linux.
# @usage    is_linux
# @os       any
is_linux() { [ "$(uname -s)" = "Linux" ]; }

# @describe Print the CPU architecture normalised to arm64 or amd64.
# @usage    os_arch
# @os       any
os_arch() {
    case "$(uname -m)" in
        arm64 | aarch64) echo arm64 ;;
        x86_64 | amd64)  echo amd64 ;;
        *) uname -m ;;
    esac
}

# @describe Print the system package manager: brew, apt, pacman, dnf, or empty.
# @usage    os_pkg_manager
# @os       any
os_pkg_manager() {
    if is_macos; then
        has brew && echo brew
        return
    fi
    if   has apt-get; then echo apt
    elif has pacman;  then echo pacman
    elif has dnf;     then echo dnf
    fi
}

# @describe Install packages using whichever package manager this machine has.
# @usage    pkg_install <package>...
# @example  pkg_install jq ripgrep fd
# @requires brew|apt-get|pacman|dnf
# @os       any
pkg_install() {
    [ $# -eq 0 ] && return 0
    case "$(os_pkg_manager)" in
        brew)   brew install "$@" ;;
        apt)    sudo apt-get update && sudo apt-get install -y "$@" ;;
        pacman) sudo pacman -S --needed --noconfirm "$@" ;;
        dnf)    sudo dnf install -y "$@" ;;
        *)      log_error "No supported package manager found. Install manually: $*" ;;
    esac
}
