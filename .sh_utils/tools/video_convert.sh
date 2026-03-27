#!/usr/bin/env zsh

webm2mp4() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -lt 1 ]; then
		cat << 'EOF'
Usage: webm2mp4 <file-without-extension> [fps]

Convert WebM video to MP4 using ffmpeg.

Arguments:
  <file-without-extension>  Base name of the file (e.g., "video" for "video.webm")
  [fps]                     Output frame rate (default: 24)

Requirements:
  - ffmpeg must be installed

Example:
  webm2mp4 recording 30
  # Converts recording.webm to recording.mp4 at 30 fps
EOF
		[ "$1" = "-h" ] || [ "$1" = "--help" ] && return 0 || return 1
	fi

	if has ffmpeg; then
		ffmpeg -fflags +genpts -i $1.webm -r ${2:-24} $1.mp4
	else
		error "ffmpeg not found."
	fi
}

gif2mp4() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -ne 1 ]; then
		cat << 'EOF'
Usage: gif2mp4 <file-without-extension>

Convert GIF to MP4 using ffmpeg with optimized settings.

Arguments:
  <file-without-extension>  Base name of the file (e.g., "animation" for "animation.gif")

Conversion settings:
  - Fast start enabled for web playback
  - YUV420p pixel format for compatibility
  - Dimensions scaled to even numbers (required for MP4)

Requirements:
  - ffmpeg must be installed

Example:
  gif2mp4 animation
  # Converts animation.gif to animation.mp4
EOF
		[ "$1" = "-h" ] || [ "$1" = "--help" ] && return 0 || return 1
	fi

	if has ffmpeg; then
		ffmpeg -i $1.gif -movflags faststart -pix_fmt yuv420p -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" $1.mp4
	else
		error "ffmpeg not found."
	fi
}

mp42png() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -lt 1 ]; then
		cat << 'EOF'
Usage: mp42png <file-without-extension> [frame]

Extract a single frame from an MP4 video as PNG.

Arguments:
  <file-without-extension>  Base name of the file (e.g., "video" for "video.mp4")
  [frame]                   Zero-based frame index (default: 0)

Requirements:
  - ffmpeg must be installed

Examples:
  mp42png video
  # Extracts first frame from video.mp4 to video.png

  mp42png video 42
  # Extracts frame #42 from video.mp4 to video.png
EOF
		[ "$1" = "-h" ] || [ "$1" = "--help" ] && return 0 || return 1
	fi

	if has ffmpeg; then
		local frame=${2:-0}
		ffmpeg -i $1.mp4 -vf "select=eq(n\,$frame)" -vframes 1 $1.png
	else
		error "ffmpeg not found."
	fi
}

avi2mp4() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -ne 1 ]; then
		cat << 'EOF'
Usage: avi2mp4 <video-path-w/o-ext>

Convert AVI to MP4 using ffmpeg with H.264 video and AAC audio.

Arguments:
  <video-path-w/o-ext>  Base name of the file (e.g., "video" for "video.avi")

Encoding settings:
  - Video codec: H.264 (libx264)
  - Video preset: medium (balanced speed/compression)
  - CRF: 23 (good quality with reasonable file size)
  - Audio codec: AAC
  - Audio bitrate: 128k

Requirements:
  - ffmpeg must be installed

Example:
  avi2mp4 recording
  # Converts recording.avi to recording.mp4
EOF
		[ "$1" = "-h" ] || [ "$1" = "--help" ] && return 0 || return 1
	fi

	if has ffmpeg; then
		local input="$1.avi"
		local output="$1.mp4"
		ffmpeg -i "$input" -c:v libx264 -preset medium -crf 23 -c:a aac -b:a 128k "$output"
	else
		error "ffmpeg not found."
	fi
}

mp42avi() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -ne 1 ]; then
		cat << 'EOF'
Usage: mp42avi <video-path-w/o-ext>

Convert MP4 to AVI using ffmpeg with mpeg4 video and mp3 audio.

Arguments:
  <video-path-w/o-ext>  Base name of the file (e.g., "video" for "video.mp4")

Encoding settings:
  - Video codec: mpeg4 (standard AVI codec)
  - Video quality: qscale 3 (good quality)
  - Audio codec: mp3 (libmp3lame)
  - Audio bitrate: 128k

Requirements:
  - ffmpeg must be installed

Example:
  mp42avi recording
  # Converts recording.mp4 to recording.avi
EOF
		[ "$1" = "-h" ] || [ "$1" = "--help" ] && return 0 || return 1
	fi

	if has ffmpeg; then
		local input="$1.mp4"
		local output="$1.avi"
		ffmpeg -i "$input" -c:v mpeg4 -qscale:v 3 -c:a libmp3lame -b:a 128k "$output"
	else
		error "ffmpeg not found."
	fi
}

mkv2mp4() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -ne 1 ]; then
		cat << 'EOF'
Usage: mkv2mp4 <video-path-w/o-ext>

Convert MKV to MP4 by remuxing (stream copy, no re-encoding).

Arguments:
  <video-path-w/o-ext>  Base name of the file (e.g., "video" for "video.mkv")

Encoding settings:
  - Video codec: copy (no re-encoding)
  - Audio codec: copy (no re-encoding)

Requirements:
  - ffmpeg must be installed

Example:
  mkv2mp4 recording
  # Converts recording.mkv to recording.mp4
EOF
		[ "$1" = "-h" ] || [ "$1" = "--help" ] && return 0 || return 1
	fi

	if has ffmpeg; then
		local input="$1.mkv"
		local output="$1.mp4"
		ffmpeg -i "$input" -c copy "$output"
	else
		error "ffmpeg not found."
	fi
}

video2gif() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -lt 1 ]; then
        cat << 'EOF'
Usage: video2gif <input> [fps=10] [width=480]

Convert video to animated GIF with palette optimization for better quality.

Arguments:
  <input>  Path to input video file
  [fps]    Frame rate for GIF (default: 10)
  [width]  Width in pixels, height scaled proportionally (default: 480)

Processing:
  - Generates optimized color palette from video
  - Uses Lanczos scaling filter for quality
  - Maintains aspect ratio

Requirements:
  - ffmpeg must be installed

Examples:
  video2gif video.mp4
  # Creates video.gif at 10 fps, 480px wide

  video2gif video.mp4 15 640
  # Creates video.gif at 15 fps, 640px wide
EOF
        [ "$1" = "-h" ] || [ "$1" = "--help" ] && return 0 || return 1
    fi

    if ! has ffmpeg; then
        error "ffmpeg not found"
        return 1
    fi

    local input="$1"
    local fps="${2:-10}"
    local width="${3:-480}"
    local output="${input%.*}.gif"

    if [ ! -f "$input" ]; then
        error "Input file not found: $input"
        return 1
    fi

    info "Converting video to GIF (fps=$fps, width=$width)..."
    if ffmpeg -i "$input" -vf "fps=$fps,scale=$width:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" -loop 0 "$output" 2>&1 | grep -q "error"; then
        error "Conversion failed"
        return 1
    fi

    completed "Created: $output"
}
