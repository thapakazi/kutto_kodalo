trace_to_svg() {
  # 1. Check for required dependencies
  local missing_deps=0
  
  if ! command -v magick &> /dev/null; then
    echo "Error: 'magick' (ImageMagick) is not installed."
    missing_deps=1
  fi
  
  if ! command -v potrace &> /dev/null; then
    echo "Error: 'potrace' is not installed."
    missing_deps=1
  fi
  
  if [ $missing_deps -ne 0 ]; then
    echo ""
    echo "You can install the missing dependencies using Homebrew:"
    echo "  brew install imagemagick potrace"
    return 1
  fi

  # 2. Check if an argument was provided
  if [ -z "$1" ]; then
    echo "Usage: trace_to_svg <input_image>"
    return 1
  fi

  local input_file="$1"

  # 3. Check if the file actually exists
  if [ ! -f "$input_file" ]; then
    echo "Error: File '$input_file' not found."
    return 1
  fi

  # 4. Extract the filename without the path and extension
  local filename=$(basename -- "$input_file")
  local base="${filename%.*}"
  
  # 5. Set the output path to /tmp
  local output_file="/tmp/${base}.svg"

  # 6. Execute the ImageMagick + Potrace pipeline
  echo "Tracing '$input_file' -> '$output_file'..."
  magick "$input_file" -background white -alpha remove pnm:- | potrace -s -o "$output_file"
  
  echo "Done!"
}
