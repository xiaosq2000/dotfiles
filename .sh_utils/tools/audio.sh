#!/usr/bin/env zsh

extract_audio() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -lt 1 ]; then
        cat << 'EOF'
Usage: extract_audio <video> [format=mp3] [bitrate=192k]

Extract audio track from video file.

Arguments:
  <video>    Path to input video file
  [format]   Output audio format (default: mp3)
  [bitrate]  Audio bitrate (default: 192k, ignored for flac/wav)

Supported formats:
  mp3   MP3 (lossy, good compatibility)
  aac   AAC (lossy, modern standard)
  ogg   Ogg Vorbis (lossy, open format)
  flac  FLAC (lossless, larger files)
  wav   WAV (uncompressed, very large files)

Requirements:
  - ffmpeg must be installed

Examples:
  extract_audio video.mp4
  # Extracts as video.mp3 at 192k

  extract_audio video.mp4 flac
  # Extracts as video.flac (lossless)

  extract_audio video.mp4 mp3 320k
  # Extracts as video.mp3 at 320k (high quality)
EOF
        [ "$1" = "-h" ] || [ "$1" = "--help" ] && return 0 || return 1
    fi

    if ! has ffmpeg; then
        error "ffmpeg not found"
        return 1
    fi

    local input="$1"
    local format="${2:-mp3}"
    local bitrate="${3:-192k}"
    local output="${input%.*}.$format"

    if [ ! -f "$input" ]; then
        error "Input file not found: $input"
        return 1
    fi

    # Map format to codec
    local codec
    case "$format" in
        mp3) codec="libmp3lame" ;;
        aac) codec="aac" ;;
        ogg) codec="libvorbis" ;;
        flac) codec="flac"; bitrate="" ;;  # flac is lossless
        wav) codec="pcm_s16le"; bitrate="" ;;  # wav is uncompressed
        *)
            error "Unsupported format: $format"
            error "Supported formats: mp3, aac, ogg, flac, wav"
            return 1
            ;;
    esac

    info "Extracting audio as $format..."
    local cmd="ffmpeg -i \"$input\" -vn -acodec $codec"
    [ -n "$bitrate" ] && cmd="$cmd -b:a $bitrate"
    cmd="$cmd \"$output\""

    if eval "$cmd" 2>&1 | grep -q "error"; then
        error "Audio extraction failed"
        return 1
    fi

    completed "Extracted: $output"
}
