#!/usr/bin/env zsh

batch_convert() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -lt 3 ]; then
        cat << 'EOF'
Usage: batch_convert <converter_func> <input_ext> <file_pattern>

Batch convert multiple files using a specified converter function.

Arguments:
  <converter_func>  Name of converter function (e.g., svg2png, jpg2png)
  <input_ext>       Input file extension without dot (e.g., svg, jpg)
  <file_pattern>    Glob pattern to match files (must be quoted)

The converter function will be called with the base filename (without extension)
for each matching file.

Examples:
  batch_convert svg2png svg '*.svg'
  # Converts all SVG files to PNG

  batch_convert jpg2png jpg 'photos/*.jpg'
  # Converts all JPG files in photos/ directory to PNG
EOF
        [ "$1" = "-h" ] || [ "$1" = "--help" ] && return 0 || return 1
    fi

    local converter="$1"
    local ext="$2"
    local pattern="$3"
    local count=0
    local failed=0

    for file in $~pattern; do
        [ -f "$file" ] || continue
        local base="${file%.$ext}"
        info "Converting: $file"
        if $converter "$base"; then
            completed "$file processed"
            ((count++))
        else
            error "Failed: $file"
            ((failed++))
        fi
    done

    if [ $count -gt 0 ]; then
        completed "Batch conversion complete: $count succeeded, $failed failed"
    else
        error "No files matched pattern: $pattern"
        return 1
    fi
}

media_info() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -ne 1 ]; then
        cat << 'EOF'
Usage: media_info <media-file>

Display media file information including duration, codec, dimensions, and bitrate.

Arguments:
  <media-file>  Path to media file (video or audio)

Displayed information:
  - Duration
  - Codec names (video and audio)
  - Video dimensions (width and height)
  - Bit rate

Requirements:
  - ffprobe must be installed

Example:
  media_info video.mp4
  # Displays detailed information about video.mp4
EOF
        [ "$1" = "-h" ] || [ "$1" = "--help" ] && return 0 || return 1
    fi

    if ! has ffprobe; then
        error "ffprobe not found"
        return 1
    fi

    if [ ! -f "$1" ]; then
        error "File not found: $1"
        return 1
    fi

    ffprobe -v error -show_format -show_streams "$1" 2>/dev/null | \
        grep -E "(duration|codec_name|width|height|bit_rate)" | \
        sed 's/^/  /'
}

get_duration() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -ne 1 ]; then
        cat << 'EOF'
Usage: get_duration <media-file>

Get duration of media file in seconds using ffprobe.

Arguments:
  <media-file>  Path to media file (video or audio)

Output:
  Duration in seconds as a decimal number

Requirements:
  - ffprobe must be installed

Example:
  duration=$(get_duration video.mp4)
  echo "Video is $duration seconds long"
EOF
        [ "$1" = "-h" ] || [ "$1" = "--help" ] && return 0 || return 1
    fi

    if ! has ffprobe; then
        error "ffprobe not found"
        return 1
    fi

    if [ ! -f "$1" ]; then
        error "File not found: $1"
        return 1
    fi

    ffprobe -v error -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 "$1" 2>/dev/null
}

validate_media() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -ne 1 ]; then
        cat << 'EOF'
Usage: validate_media <media-file>

Validate media file integrity using ffprobe.

Arguments:
  <media-file>  Path to media file (video or audio)

Validation:
  - Checks if file can be read and parsed
  - Verifies container and stream integrity
  - Returns success if file is valid, error if corrupted

Requirements:
  - ffprobe must be installed

Example:
  validate_media video.mp4 && echo "File is valid"
EOF
        [ "$1" = "-h" ] || [ "$1" = "--help" ] && return 0 || return 1
    fi

    if ! has ffprobe; then
        error "ffprobe not found"
        return 1
    fi

    local input="$1"

    if [ ! -f "$input" ]; then
        error "File not found: $input"
        return 1
    fi

    info "Validating: $input"
    if ffprobe -v error "$input" 2>/dev/null; then
        completed "$input is valid"
        return 0
    else
        error "$input is corrupted or invalid"
        return 1
    fi
}

list_media_tools() {
    # Display all available media conversion and processing tools
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "                    MEDIA TOOLS REFERENCE                      "
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "IMAGE CONVERSION:"
    echo "  svg2pdf <file>              - Convert SVG to PDF"
    echo "  svg2png <file>              - Convert SVG to PNG (high quality)"
    echo "  webp2png <file>             - Convert WebP to PNG"
    echo "  jpg2png <file>              - Convert JPG to PNG"
    echo ""
    echo "IMAGE PROCESSING:"
    echo "  resize_image <in> <size> [out]     - Resize image (e.g., 50%, 800x600)"
    echo "  thumbnail <input> [output]         - Create 200x200 thumbnail"
    echo "  invert_color <in> [out]            - Invert image colors"
    echo "  transparent_bg <in> [out] [color] [fuzz] - Make background transparent"
    echo "  process_image <input>              - Transparent bg + invert colors"
    echo "  add_watermark <in> <wm> [pos] [out] - Add watermark to image"
    echo "  compress_image <in> [quality] [out]  - Compress PNG/JPEG image"
    echo "  concat_images [opts] <img1> <img2>...  - Concat images h/v"
    echo ""
    echo "VIDEO CONVERSION:"
    echo "  webm2mp4 <file> [fps]       - Convert WebM to MP4"
    echo "  gif2mp4 <file>              - Convert GIF to MP4"
    echo "  avi2mp4 <file>              - Convert AVI to MP4"
    echo "  mp42avi <file>              - Convert MP4 to AVI"
    echo "  mkv2mp4 <file>              - Convert MKV to MP4 (remux)"
    echo "  video2gif <file> [fps] [width] - Convert video to animated GIF"
    echo ""
    echo "VIDEO PROCESSING:"
    echo "  trim_video <in> <start> <dur> [out] - Trim video segment"
    echo "  concat_videos <out> <v1> <v2> ...   - Merge multiple videos"
    echo "  insert_image <vid> <img> <dur> [pos] [out] - Add image before/after video"
    echo "  speedup_video <in> [factor] [out]    - Speed up video (default 2x)"
    echo "  compress_video <in> [crf] [out]     - Compress video (MP4/AVI, keeps format)"
    echo "  mp42png <file> [frame]              - Extract frame as PNG"
    echo "  mp3mp42mp4 <audio> <video> <out> [opts] - Combine MP3 + MP4"
    echo ""
    echo "AUDIO:"
    echo "  extract_audio <video> [fmt] [bitrate] - Extract audio (mp3/aac/ogg/flac/wav)"
    echo ""
    echo "PDF:"
    echo "  compress_pdf <input> <output>  - Compress PDF file"
    echo "  concat_pdfs <out> <in1> <in2>...  - Merge multiple PDFs"
    echo "  pdf2img <file> [opts]          - Convert one-page PDF to PNG/JPG"
    echo ""
    echo "UTILITIES:"
    echo "  media_info <file>           - Show media file info"
    echo "  get_duration <file>         - Get media duration in seconds"
    echo "  validate_media <file>       - Check media file integrity"
    echo "  batch_convert <func> <ext> <pattern> - Batch process files"
    echo ""
    echo "NOTIFICATIONS:"
    echo "  command_with_email_notification <cmd> [dir] [email]"
    echo "                              - Run command and email results"
    echo ""
    echo "Tip: Most commands support -h or --help for detailed usage."
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
}
