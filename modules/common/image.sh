# @module image
# @summary Raster-to-vector tracing with ImageMagick and potrace.

require magick potrace || return 0

# @describe Trace a raster image to a vector SVG. The image is flattened onto a
#           white background, converted to PNM, then traced by potrace. Output
#           defaults to <input>.svg beside the input.
# @usage    image_trace_to_svg <input-image> [output.svg]
# @example  image_trace_to_svg logo.png
# @example  image_trace_to_svg scan.jpg ~/Desktop/scan.svg
# @requires magick potrace
# @os       any
# @danger   Overwrites <output.svg> when it already exists — prompts first.
image_trace_to_svg() {
    local input="$1" output="${2:-}"

    if [ -z "$input" ]; then
        log_error "usage: image_trace_to_svg <input-image> [output.svg]"
        return 1
    fi

    if [ ! -f "$input" ]; then
        log_error "image_trace_to_svg: no such file: $input"
        return 1
    fi

    output="${output:-${input%.*}.svg}"

    if [ -e "$output" ]; then
        confirm "Overwrite $output?" || return 0
    fi

    log_info "Tracing $input -> $output"
    magick "$input" -background white -alpha remove pnm:- | potrace -s -o "$output" || {
        log_error "image_trace_to_svg: tracing failed"
        return 1
    }

    log_ok "Wrote $output ($(path_size "$output"))"
}

# ------------------------------------------------------------------ aliases --

alias trace_to_svg='image_trace_to_svg'
