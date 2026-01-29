
# --- OS Helpers ---
get_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "mac"
    elif [[ "$OSTYPE" == "linux"* ]]; then
        echo "linux"
    else
        echo "what, you an alien ??"
    fi
}

if_mac()   { [[ "$(get_os)" == "mac" ]]; }
if_linux() { [[ "$(get_os)" == "linux" ]]; }
if_alien() { [[ "$(get_os)" == *"alien"* ]]; }

# Helper to find the right package manager for Linux
get_linux_pm() {
    if command -v apt-get &>/dev/null; then echo "apt-get";
    elif command -v pacman &>/dev/null; then echo "pacman";
    elif command -v dnf &>/dev/null; then echo "dnf";
    fi
}

# --- Core Function ---

install_deps() {
    local pkgs=("$@")
    if [ ${#pkgs[@]} -eq 0 ]; then return 0; fi

    if if_alien; then
        echo "Contacting mothership... (Error: OS not supported)"
        return 1
    fi

    echo "Preparing to install: ${pkgs[*]}"

    if if_mac; then
        if command -v brew &>/dev/null; then
            brew install "${pkgs[@]}"
        else
            echo "Homebrew not found. Please install it first or install packages manually."
            return 1
        fi
    fi

    if if_linux; then
        local pm=$(get_linux_pm)
        case "$pm" in
            apt-get) sudo apt-get update && sudo apt-get install -y "${pkgs[@]}" ;;
            pacman)  sudo pacman -Sy --noconfirm "${pkgs[@]}" ;;
            dnf)     sudo dnf install -y "${pkgs[@]}" ;;
            *)       echo "Unknown package manager. Install manually: ${pkgs[*]}" ; return 1 ;;
        esac
    fi
}

# --- Usage Example ---

# case "$1" in
#     install)
#         # Shift away 'install' and pass the rest as packages
#         install_deps "${@:2}"
#         ;;
#     setup-pass)
#         # Specific shortcut for your GPG/Pass requirements
#         install_deps gnupg zip unzip
#         ;;
#     *)
#         echo "Usage:"
#         echo "  $0 install <pkgs>   - Install any package"
#         echo "  $0 setup-pass      - Install GPG and Zip tools"
#         ;;
# esac
