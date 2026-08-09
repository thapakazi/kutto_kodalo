# @module colors
# @summary Terminal colour constants. Honours NO_COLOR and non-tty output.
#
# All names are C_ prefixed to keep the global namespace clean. Colours resolve
# to empty strings when stdout is not a terminal or NO_COLOR is set, so callers
# never need to branch — just interpolate them.

if [ -t 1 ] && [ -z "$NO_COLOR" ] && [ "$TERM" != "dumb" ]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'

    C_BLACK=$'\033[0;30m'
    C_RED=$'\033[0;31m'
    C_GREEN=$'\033[0;32m'
    C_YELLOW=$'\033[0;33m'
    C_BLUE=$'\033[0;34m'
    C_PURPLE=$'\033[0;35m'
    C_CYAN=$'\033[0;36m'
    C_WHITE=$'\033[0;37m'

    C_B_RED=$'\033[1;31m'
    C_B_GREEN=$'\033[1;32m'
    C_B_YELLOW=$'\033[1;33m'
    C_B_BLUE=$'\033[1;34m'
    C_B_PURPLE=$'\033[1;35m'
    C_B_CYAN=$'\033[1;36m'
else
    C_RESET='' C_BOLD='' C_DIM=''
    C_BLACK='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_PURPLE='' C_CYAN='' C_WHITE=''
    C_B_RED='' C_B_GREEN='' C_B_YELLOW='' C_B_BLUE='' C_B_PURPLE='' C_B_CYAN=''
fi
