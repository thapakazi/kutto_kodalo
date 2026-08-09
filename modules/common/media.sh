# @module media
# @summary ffmpeg video helpers: re-encode a file down to a sane size and report
#          the before/after saving.

require ffmpeg || return 0

# Encoder settings. Override in modules/local/ or the environment.
#   libx264 is the default because it plays everywhere — every browser, phone,
#   TV and editor decodes it, usually in hardware. libx265 gives roughly 30%
#   smaller files at the same CRF; set MEDIA_VIDEO_CODEC=libx265 if every
#   consumer of the output can decode HEVC.
MEDIA_VIDEO_CODEC="${MEDIA_VIDEO_CODEC:-libx264}"
MEDIA_VIDEO_CRF="${MEDIA_VIDEO_CRF:-28}"
MEDIA_AUDIO_CODEC="${MEDIA_AUDIO_CODEC:-aac}"
MEDIA_AUDIO_BITRATE="${MEDIA_AUDIO_BITRATE:-128k}"

# Set to 1 to open the result in the desktop viewer when the encode finishes.
# Off by default: opening a window per file is hostile in a batch loop.
MEDIA_OPEN_AFTER="${MEDIA_OPEN_AFTER:-0}"

# @describe Re-encode a video to a smaller MP4 and report the size saved.
#           Defaults to H.264 CRF 28 with faststart so the result streams.
#           Output defaults to <input>_shrunk.mp4 next to the input.
# @usage    media_shrink_video <input> [output]
# @example  media_shrink_video screencast.mov
# @example  media_shrink_video raw.mp4 /tmp/small.mp4
# @example  MEDIA_VIDEO_CODEC=libx265 MEDIA_VIDEO_CRF=30 media_shrink_video big.mp4
# @example  MEDIA_OPEN_AFTER=1 media_shrink_video clip.mov
# @requires ffmpeg
# @os       any
# @danger   Overwrites <output> when it already exists — prompts first.
media_shrink_video() {
    local input="$1" output="${2:-}" size_before="" size_after=""

    if [ -z "$input" ] || [ ! -f "$input" ]; then
        log_error "usage: media_shrink_video <input> [output]"
        return 1
    fi

    output="${output:-${input%.*}_shrunk.mp4}"

    if [ "$output" = "$input" ]; then
        log_error "media_shrink_video: output would overwrite the input"
        return 1
    fi

    if [ -e "$output" ]; then
        confirm "Overwrite $output?" || return 0
    fi

    size_before="$(path_size "$input")"
    log_info "Compressing: $input ($size_before)"

    ffmpeg -hide_banner -loglevel error -stats \
           -i "$input" \
           -c:v "$MEDIA_VIDEO_CODEC" \
           -crf "$MEDIA_VIDEO_CRF" \
           -c:a "$MEDIA_AUDIO_CODEC" \
           -b:a "$MEDIA_AUDIO_BITRATE" \
           -movflags +faststart \
           -y "$output" || { log_error "media_shrink_video: encode failed"; return 1; }

    if [ ! -f "$output" ]; then
        log_error "media_shrink_video: no output produced"
        return 1
    fi

    size_after="$(path_size "$output")"
    log_ok "Finished: $output ($size_before -> $size_after)"

    [ "$MEDIA_OPEN_AFTER" = "1" ] && os_open "$output"
    return 0
}

# ------------------------------------------------------------------ aliases --

alias reduce_video_size='media_shrink_video'
