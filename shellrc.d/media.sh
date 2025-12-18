# Optimized function to reduce video size using FFmpeg
reduce_video_size() {

    # Check if input file exists
    if [[ -z "$1" ]] || [[ ! -f "$1" ]]; then
        echo "Usage: reduce_video_size input_file.xxx [output_file.yyy]"
        return 1
    fi

    # check if ffmpeg exists
    if ! command -v ffmpeg &> /dev/null; then
        echo "Error: FFmpeg is not installed."
        echo "Please install it using your package manager:"
        echo "  - macOS: brew install ffmpeg"
        echo "  - Ubuntu/Debian: sudo apt update && sudo apt install ffmpeg"
        echo "  - Windows: winget install ffmpeg"
        return 1
    fi

    local input="$1"
    local output="${2:-${input%.*}_shrunk.mp4}"

    # Capture initial size
    local size_before
    size_before=$(du -sh "$input" | awk '{print $1}')

    echo "Compressing: '$input' ($size_before)"

    
    # FFmpeg 2025 Best Practices:
    # -c:v libx265: Higher efficiency than x264 for smaller files
    # -crf 28: Strong compression while maintaining good 1080p quality
    # -movflags +faststart: Optimizes the MP4 for web streaming
    ffmpeg -i "$input" \
           -c:v libx264 \
           -crf 28 \
           -c:a aac \
           -b:a 128k \
           -movflags +faststart \
           -y "$output" > /dev/null 2>&1

    # Check if output was actually created
    if [[ -f "$output" ]]; then
        local size_after
        size_after=$(du -sh "$output" | awk '{print $1}')
        
        echo "Finished:    '$output' ($size_after)"
        echo "Reduction:   $size_before -> $size_after"
        
        # Optional: Open file (macOS)
        [[ "$OSTYPE" == "darwin"* ]] && open "$output"
    else
        echo "Error: Compression failed."
        return 1
    fi
}
