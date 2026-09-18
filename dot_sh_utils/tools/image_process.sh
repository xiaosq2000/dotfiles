#!/usr/bin/env zsh

invert_color() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -lt 1 ] || [ $# -gt 2 ]; then
        cat << 'EOF'
Usage: invert_color <input-img-path> [output-img-path]

Invert image colors by negating the lightness channel in HSL color space.

Arguments:
  <input-img-path>   Path to input image file
  [output-img-path]  Path to output image (default: <input>-dark.<ext>)

Processing:
  - Converts to HSL color space
  - Negates the Lightness channel
  - Converts back to sRGB color space

Requirements:
  - ImageMagick's convert must be installed

Examples:
  invert_color photo.png
  # Creates photo-dark.png

  invert_color photo.png inverted.png
  # Creates inverted.png
EOF
        [ "$1" = "-h" ] || [ "$1" = "--help" ] && return 0 || return 1
    fi

    if ! has convert; then
        error "Error: ImageMagick's convert not found"
        return 1
    fi

    local input="$1"
    local output

    if [ $# -eq 2 ]; then
        output="$2"
    else
        local base="${input%.*}"
        local ext="${input##*.}"
        output="${base}-dark.${ext}"
    fi

    convert $input -colorspace HSL -channel L -negate -colorspace SRGB $output
    return $?
}

transparent_bg() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -lt 1 ]; then
        cat << 'EOF'
Usage: transparent_bg <input> [output] [bg_color] [fuzz]

Make a solid background color transparent using ImageMagick.

Arguments:
  <input>      Path to input image file
  [output]     Path to output image (default: overwrites input)
  [bg_color]   Background color to make transparent (default: white)
               Can be color name or hex code (e.g., '#FF0000')
  [fuzz]       Color tolerance percentage (default: 0.1%)

Requirements:
  - ImageMagick's convert must be installed

Examples:
  transparent_bg image.png
  # Makes white background transparent in-place

  transparent_bg image.png output.png
  # Saves result to output.png

  transparent_bg image.png output.png '#00FF00' 5%
  # Makes green background transparent with 5% tolerance
EOF
        [ "$1" = "-h" ] || [ "$1" = "--help" ] && return 0 || return 1
    fi

    if ! has convert; then
        error "Error: ImageMagick's convert not found"
        return 1
    fi

    local input="$1"
    local output="${2:-$1}"
    local bg_color="${3:-"white"}"
    local fuzz="${4:-"0.1%"}"

    convert "$input" -fuzz "$fuzz" -transparent "$bg_color" "$output"
    return $?
}

process_image() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -ne 1 ]; then
        cat << 'EOF'
Usage: process_image <input-img-path>

Make background transparent and then invert colors (in-place processing).

Arguments:
  <input-img-path>  Path to input image file (will be modified in-place)

Processing steps:
  1. Makes white background transparent
  2. Inverts colors using HSL lightness negation

Requirements:
  - ImageMagick's convert must be installed

Example:
  process_image diagram.png
  # Makes background transparent and inverts colors
EOF
        [ "$1" = "-h" ] || [ "$1" = "--help" ] && return 0 || return 1
    fi

    local input="$1"

    # First make background transparent
    if ! transparent_bg "$input"; then
        error "Failed to make background transparent"
        return 1
    fi

    # Then invert colors
    if ! invert_color "$input"; then
        error "Failed to invert colors"
        return 1
    fi

    return 0
}

resize_image() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -lt 2 ]; then
        cat << 'EOF'
Usage: resize_image <input> <size> [output]

Resize image to specified dimensions or percentage using ImageMagick.

Arguments:
  <input>   Path to input image file
  <size>    Resize specification (see formats below)
  [output]  Path to output file (default: <input>_resized.<ext>)

Size format examples:
  50%       Scale to 50% of original size
  800x600   Fit within 800x600 (maintains aspect ratio)
  800x600!  Force exact size (ignores aspect ratio)
  800x600>  Only shrink if larger than 800x600
  800x600<  Only enlarge if smaller than 800x600

Requirements:
  - ImageMagick's convert must be installed

Examples:
  resize_image photo.jpg 50%
  # Scales to half size as photo_resized.jpg

  resize_image photo.jpg 1920x1080 small.jpg
  # Fits within 1920x1080, saves to small.jpg
EOF
        [ "$1" = "-h" ] || [ "$1" = "--help" ] && return 0 || return 1
    fi

    if ! has convert; then
        error "ImageMagick's convert not found"
        return 1
    fi

    local input="$1"
    local size="$2"
    local output="${3:-${input%.*}_resized.${input##*.}}"

    if [ ! -f "$input" ]; then
        error "Input file not found: $input"
        return 1
    fi

    if convert "$input" -resize "$size" "$output"; then
        completed "Resized: $output"
        return 0
    else
        error "Resize failed"
        return 1
    fi
}

thumbnail() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -lt 1 ]; then
        cat << 'EOF'
Usage: thumbnail <input> [output]

Create a 200x200 thumbnail from an image (maintains aspect ratio).

Arguments:
  <input>   Path to input image file
  [output]  Path to output file (default: <input>_thumb.<ext>)

Processing:
  - Resizes to fit within 200x200 pixels
  - Maintains original aspect ratio

Requirements:
  - ImageMagick's convert must be installed

Example:
  thumbnail photo.jpg
  # Creates photo_thumb.jpg at 200x200 max
EOF
        [ "$1" = "-h" ] || [ "$1" = "--help" ] && return 0 || return 1
    fi

    local input="$1"
    local output="${2:-${input%.*}_thumb.${input##*.}}"
    resize_image "$input" "200x200" "$output"
}

add_watermark() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -lt 2 ]; then
        cat << 'EOF'
Usage: add_watermark <input> <watermark> [position=southeast] [output]

Add watermark image to another image using ImageMagick.

Arguments:
  <input>      Path to input image file
  <watermark>  Path to watermark image file
  [position]   Watermark position (default: southeast)
  [output]     Path to output file (default: <input>_watermarked.<ext>)

Position options:
  northwest  north  northeast
  west       center east
  southwest  south  southeast

Processing:
  - Watermark is placed with 10px offset from edges
  - Preserves original image quality

Requirements:
  - ImageMagick's convert must be installed

Examples:
  add_watermark photo.jpg logo.png
  # Adds logo to bottom-right corner

  add_watermark photo.jpg logo.png northwest branded.jpg
  # Adds logo to top-left, saves to branded.jpg
EOF
        [ "$1" = "-h" ] || [ "$1" = "--help" ] && return 0 || return 1
    fi

    if ! has convert; then
        error "ImageMagick's convert not found"
        return 1
    fi

    local input="$1"
    local watermark="$2"
    local position="${3:-southeast}"
    local output="${4:-${input%.*}_watermarked.${input##*.}}"

    if [ ! -f "$input" ]; then
        error "Input file not found: $input"
        return 1
    fi

    if [ ! -f "$watermark" ]; then
        error "Watermark file not found: $watermark"
        return 1
    fi

    # Validate position
    case "$position" in
        northwest|north|northeast|west|center|east|southwest|south|southeast) ;;
        *)
            error "Invalid position: $position"
            error "Valid positions: northwest, north, northeast, west, center, east, southwest, south, southeast"
            return 1
            ;;
    esac

    info "Adding watermark at $position..."
    if convert "$input" "$watermark" -gravity "$position" -geometry +10+10 -composite "$output"; then
        completed "Watermarked: $output"
        return 0
    else
        error "Watermarking failed"
        return 1
    fi
}

compress_image() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -lt 1 ]; then
        cat << 'EOF'
Usage: compress_image <input> [quality=85] [output]

Compress a PNG or JPEG image using ImageMagick.

Arguments:
  <input>    Path to input image (png, jpg, jpeg)
  [quality]  Compression quality 1-100 (default: 85)
             JPEG: lower = smaller file, more artifacts
             PNG: lossless compression only (quality ignored); strips metadata
  [output]   Path to output file (default: <input>_compressed.<ext>)

Processing:
  - Strips metadata (EXIF, ICC profiles, comments, etc.)
  - JPEG: lossy compression at specified quality + progressive encoding
  - PNG: maximum lossless zlib compression (level 9)

Requirements:
  - ImageMagick's convert must be installed

Examples:
  compress_image photo.jpg
  # Compresses photo.jpg at quality 85

  compress_image photo.jpg 70 small.jpg
  # Compresses at quality 70, saves to small.jpg

  compress_image screenshot.png
  # Strips metadata and applies max lossless compression
EOF
        [ "$1" = "-h" ] || [ "$1" = "--help" ] && return 0 || return 1
    fi

    if ! has convert; then
        error "ImageMagick's convert not found"
        return 1
    fi

    local input="$1"
    local quality="${2:-85}"
    local output="${3:-${input%.*}_compressed.${input##*.}}"

    if [ ! -f "$input" ]; then
        error "Input file not found: $input"
        return 1
    fi

    local ext="${input##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

    case "$ext" in
        jpg|jpeg)
            if [ "$quality" -lt 1 ] || [ "$quality" -gt 100 ]; then
                error "Quality must be between 1 and 100"
                return 1
            fi
            info "Compressing JPEG at quality $quality..."
            if ! convert "$input" -strip -interlace Plane -quality "$quality" "$output"; then
                error "Compression failed"
                return 1
            fi
            ;;
        png)
            info "Compressing PNG (lossless, strip metadata)..."
            if ! convert "$input" -strip -define png:compression-level=9 "$output"; then
                error "Compression failed"
                return 1
            fi
            ;;
        *)
            error "Unsupported format: $ext (supported: png, jpg, jpeg)"
            return 1
            ;;
    esac

    local orig_size=$(du -h "$input" | cut -f1)
    local new_size=$(du -h "$output" | cut -f1)
    completed "Compressed: $orig_size → $new_size ($output)"
}

concat_images() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -lt 2 ]; then
        cat << 'EOF'
Usage: concat_images [options] <image1> <image2> [image3...]

Concatenate multiple images horizontally or vertically using ImageMagick.

Options:
  -v, --vertical    Stack images vertically (default: horizontal)
  -g, --gap N       Gap between images in pixels (default: 0)
  -b, --bg COLOR    Background/gap color (default: none/transparent)
  -o, --output FILE Output file path (default: concat_h.<ext> or concat_v.<ext>)

Arguments:
  <image1> <image2> [image3...]  Two or more image files to concatenate

Processing:
  - Horizontal: images are placed left to right (+append)
  - Vertical: images are stacked top to bottom (-append)
  - Images with different dimensions are aligned to the top/left edge

Requirements:
  - ImageMagick's convert must be installed

Examples:
  concat_images a.png b.png
  # Concatenates horizontally, saves to concat_h.png

  concat_images -v a.png b.png c.png
  # Stacks vertically, saves to concat_v.png

  concat_images -g 10 -b white -o merged.png a.png b.png
  # Horizontal with 10px white gap, saves to merged.png
EOF
        [ "$1" = "-h" ] || [ "$1" = "--help" ] && return 0 || return 1
    fi

    if ! has convert; then
        error "ImageMagick's convert not found"
        return 1
    fi

    local vertical=false
    local gap=0
    local bg="none"
    local output=""

    # Parse named arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
        -v | --vertical)
            vertical=true
            shift
            ;;
        -g | --gap)
            gap="$2"
            shift 2
            ;;
        -b | --bg)
            bg="$2"
            shift 2
            ;;
        -o | --output)
            output="$2"
            shift 2
            ;;
        *)
            break
            ;;
        esac
    done

    if [ $# -lt 2 ]; then
        error "At least two images are required"
        return 1
    fi

    # Validate all input files exist
    for img in "$@"; do
        if [ ! -f "$img" ]; then
            error "File not found: $img"
            return 1
        fi
    done

    # Determine default output name from first input extension
    if [ -z "$output" ]; then
        local ext="${1##*.}"
        if [ "$vertical" = true ]; then
            output="concat_v.$ext"
        else
            output="concat_h.$ext"
        fi
    fi

    local append_flag="+append"
    local direction="horizontally"
    if [ "$vertical" = true ]; then
        append_flag="-append"
        direction="vertically"
    fi

    info "Concatenating $# images $direction..."

    if [ "$gap" -gt 0 ] 2>/dev/null; then
        # Insert gap by using -splice between images via a smush operation
        # smush is like append but with a gap parameter
        local smush_flag="+smush"
        [ "$vertical" = true ] && smush_flag="-smush"

        if convert "$@" -background "$bg" $smush_flag "$gap" "$output"; then
            completed "Created: $output"
            return 0
        else
            error "Concatenation failed"
            return 1
        fi
    else
        if convert "$@" -background "$bg" $append_flag "$output"; then
            completed "Created: $output"
            return 0
        else
            error "Concatenation failed"
            return 1
        fi
    fi
}
