# @module android
# @summary Mirror an Android phone over adb with scrcpy: screen, front camera,
#          and "throw this YouTube URL on the phone" shortcuts.

require adb scrcpy || return 0

# Window title used by the screen-mirroring entry points.
ANDROID_MIRROR_TITLE="${ANDROID_MIRROR_TITLE:-/dev/phone}"

# ------------------------------------------------------------------ private --

# Base scrcpy invocation shared by every mirroring function: prefer the wireless
# connection and float the window above everything else.
_android_scrcpy() {
    scrcpy --select-tcpip --always-on-top "$@"
}

# First connected device serial, or empty.
_android_first_device() {
    android_list_devices | head -n 1
}

# ------------------------------------------------------------------- public --

# @describe Print the serial of every connected adb device, one per line.
# @usage    android_list_devices
# @example  android_list_devices
# @example  adb -s "$(android_list_devices | head -n 1)" shell getprop ro.product.model
# @requires adb
# @os       any
android_list_devices() {
    adb devices -l | awk 'NR>1 && NF {print $1}'
}

# @describe Mirror the phone screen in a floating, titled window. Any extra
#           arguments are passed straight through to scrcpy.
# @usage    android_mirror [scrcpy-args...]
# @example  android_mirror
# @example  android_mirror --max-size=1024 --turn-screen-off
# @requires scrcpy adb
# @os       any
# @see      android_mirror_camera
android_mirror() {
    _android_scrcpy --window-title="$ANDROID_MIRROR_TITLE" "$@"
}

# @describe Mirror the phone's front camera as a square, rotated feed — useful
#           as a webcam source. Extra arguments pass through to scrcpy.
# @usage    android_mirror_camera [scrcpy-args...]
# @example  android_mirror_camera
# @example  android_mirror_camera --camera-facing=back --camera-ar=16:9
# @requires scrcpy adb
# @os       any
# @see      android_mirror
android_mirror_camera() {
    _android_scrcpy \
        --video-source=camera \
        --orientation=270 \
        --camera-facing=front \
        --camera-ar=1:1 \
        "$@"
}

# @describe Open a YouTube URL in the phone's YouTube app, then mirror the
#           screen with the URL in the window title. Extra arguments pass
#           through to scrcpy.
# @usage    android_open_youtube <url> [scrcpy-args...]
# @example  android_open_youtube https://youtu.be/dQw4w9WgXcQ
# @example  android_open_youtube https://youtu.be/dQw4w9WgXcQ --max-size=1024
# @requires adb scrcpy
# @os       any
# @see      android_mirror
android_open_youtube() {
    local url="$1" device=""

    if [ -z "$url" ]; then
        log_error "usage: android_open_youtube <url> [scrcpy-args...]"
        return 1
    fi
    [ $# -gt 0 ] && shift

    device="$(_android_first_device)"
    if [ -z "$device" ]; then
        log_error "android: no adb device connected"
        return 1
    fi

    adb -s "$device" shell am start \
        -a android.intent.action.VIEW \
        -d "$url" \
        com.google.android.youtube || return 1

    _android_scrcpy --window-title="youtube:: $url" "$@"
}

# ------------------------------------------------------------------ aliases --

alias m_p='android_mirror'
alias m_p_cam='android_mirror_camera'
alias m_pyt='android_open_youtube'
