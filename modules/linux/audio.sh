# @module audio
# @summary ALSA microphone helpers for when the mic has stopped working again.
#
# https://wiki.archlinux.org/index.php/Advanced_Linux_Sound_Architecture/Troubleshooting#Microphone

require arecord aplay || return 0

# @describe Record from the default input to a temporary WAV and print its path.
# @usage    audio_record_mic [seconds]
# @example  audio_record_mic 10
# @requires arecord
# @os       linux
audio_record_mic() {
    local seconds="${1:-10}" out
    out=$(tmp_file mic) || return 1
    log_info "recording ${seconds}s — say something"
    if arecord -d "$seconds" -f dat "$out"; then
        log_ok "saved to $out"
        printf '%s\n' "$out"
    else
        rm -f "$out"
        return 1
    fi
}

# @describe Record a short clip, play it straight back, then delete it. The
#           quickest way to tell whether the mic is alive.
# @usage    audio_test_mic [seconds]
# @example  audio_test_mic 5
# @requires arecord aplay
# @os       linux
audio_test_mic() {
    local clip
    # The original called `exit` when recording failed, which killed the
    # interactive shell rather than the function.
    clip=$(audio_record_mic "${1:-5}") ||
        { log_error "recording failed"; return 1; }

    aplay "$clip"
    local rc=$?
    rm -f "$clip"
    return "$rc"
}

# @describe Pipe the microphone straight to the speakers. Runs until Ctrl-C.
#           Wear headphones unless you enjoy feedback.
# @usage    audio_mic_to_speaker
# @example  audio_mic_to_speaker
# @requires arecord aplay
# @os       linux
# @see      https://askubuntu.com/a/887658
audio_mic_to_speaker() {
    log_info "mic → speakers, Ctrl-C to stop"
    arecord -f cd - | aplay -
}
