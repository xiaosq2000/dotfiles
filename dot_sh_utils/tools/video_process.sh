#!/usr/bin/env zsh

mp3mp42mp4() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		cat << 'EOF'
Usage: mp3mp42mp4 [options] <input_audio.mp3> <input_video.mp4> <output.mp4>

Combine an MP3 audio file with an MP4 video file using ffmpeg.

Options:
  -f, --force       Overwrite output file if it exists
  -q, --quality N   Audio quality in kbps (32-320, default: 192)
  -v, --volume N    Adjust audio volume (0.0-10.0, default: 1.0)

Arguments:
  <input_audio.mp3>  Path to MP3 audio file
  <input_video.mp4>  Path to MP4 video file
  <output.mp4>       Path to output MP4 file

Behavior:
  - If audio is longer than video, audio speed is adjusted to match
  - If audio is shorter or equal, only volume is adjusted
  - Video codec is copied (no re-encoding)
  - Audio is re-encoded to AAC at specified bitrate

Requirements:
  - ffmpeg and ffprobe must be installed

Examples:
  mp3mp42mp4 audio.mp3 video.mp4 output.mp4
  mp3mp42mp4 -f -q 256 -v 1.5 audio.mp3 video.mp4 output.mp4
EOF
		return 0
	fi

	local FORCE=0
	local AUDIO_BITRATE="192k"
	local VOLUME=1.0

	# Parse named arguments
	while [[ $# -gt 0 ]]; do
		case $1 in
		-f | --force)
			FORCE=1
			shift
			;;
		-q | --quality)
			AUDIO_BITRATE="${2}k"
			shift 2
			;;
		-v | --volume)
			VOLUME="$2"
			shift 2
			;;
		*)
			break
			;;
		esac
	done

	# Check for required arguments
	if [ $# -ne 3 ]; then
		echo "Error: Missing required arguments" >&2
		echo "Usage: mp3mp42mp4 [options] <input_audio.mp3> <input_video.mp4> <output.mp4>" >&2
		echo "Options:" >&2
		echo "  -f, --force     : Overwrite output file if it exists" >&2
		echo "  -q, --quality N : Audio quality (32-320, default: 192)" >&2
		echo "  -v, --volume N  : Adjust audio volume (0.0-10.0, default: 1.0)" >&2
		return 1
	fi

	# Check if ffmpeg is installed
	if ! command -v ffmpeg >/dev/null 2>&1; then
		echo "Error: ffmpeg is not installed" >&2
		return 1
	fi

	local audio="$1"
	local video="$2"
	local output="$3"

	# Validate input files exist
	for file in "$audio" "$video"; do
		if [ ! -f "$file" ]; then
			echo "Error: File not found: $file" >&2
			return 1
		fi
	done

	# Check output file
	if [ -f "$output" ] && [ $FORCE -eq 0 ]; then
		echo "Error: Output file already exists. Use -f to force overwrite." >&2
		return 1
	fi

	# Improved file validation
	if ! ffprobe -v error "$audio" 2>/dev/null; then
		echo "Error: Cannot read audio file: $audio" >&2
		return 1
	fi

	if ! ffprobe -v error "$video" 2>/dev/null; then
		echo "Error: Cannot read video file: $video" >&2
		return 1
	fi

	# Get durations (with error checking)
	local video_duration
	local audio_duration

	video_duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$video" 2>/dev/null)
	if [ $? -ne 0 ] || [ -z "$video_duration" ]; then
		echo "Error: Could not determine video duration" >&2
		return 1
	fi

	audio_duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$audio" 2>/dev/null)
	if [ $? -ne 0 ] || [ -z "$audio_duration" ]; then
		echo "Error: Could not determine audio duration" >&2
		return 1
	fi

	# Calculate speed factor if audio is longer than video
	local speed_factor=1.0
	if (($(echo "$audio_duration > $video_duration" | bc -l))); then
		speed_factor=$(echo "scale=4; $audio_duration/$video_duration" | bc)
		echo "Info: Audio duration ($audio_duration s) longer than video ($video_duration s)" >&2
		echo "Info: Adjusting audio speed by factor $speed_factor" >&2
	fi

	# Create temporary directory
	local temp_dir=$(mktemp -d)
	local temp_output="${temp_dir}/temp_output.mp4"

	# Cleanup function
	cleanup() {
		rm -rf "$temp_dir"
	}
	trap cleanup EXIT

	# Process the files
	if (($(echo "$audio_duration > $video_duration" | bc -l))); then
		# If audio is longer, adjust its speed
		if ! ffmpeg -i "$video" -i "$audio" \
			-filter_complex "[1:a]atempo=$speed_factor,volume=$VOLUME" \
			-c:v copy -c:a aac -b:a "$AUDIO_BITRATE" \
			-map 0:v:0 -map 1:a:0 \
			-shortest \
			-movflags +faststart \
			"$temp_output" 2>&1; then

			echo "Error: Failed to process files" >&2
			return 1
		fi
	else
		# If audio is shorter or equal, just adjust volume
		if ! ffmpeg -i "$video" -i "$audio" \
			-filter_complex "[1:a]volume=$VOLUME" \
			-c:v copy -c:a aac -b:a "$AUDIO_BITRATE" \
			-map 0:v:0 -map 1:a:0 \
			-shortest \
			-movflags +faststart \
			"$temp_output" 2>&1; then

			echo "Error: Failed to process files" >&2
			return 1
		fi
	fi

	# Move temporary file to final destination
	if ! mv "$temp_output" "$output"; then
		echo "Error: Failed to move temporary file to final destination" >&2
		return 1
	fi

	echo "Success: Created $output" >&2
	return 0
}

trim_video() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -lt 3 ]; then
        cat << 'EOF'
Usage: trim_video <input> <start_time> <duration> [output]

Trim/cut a video segment from start time with specified duration.

Arguments:
  <input>       Path to input video file
  <start_time>  Starting position (format: HH:MM:SS or seconds)
  <duration>    Duration to extract (format: HH:MM:SS or seconds)
  [output]      Path to output file (default: <input>_trimmed.<ext>)

Processing:
  - Uses stream copy (no re-encoding) for fast processing

Requirements:
  - ffmpeg must be installed

Examples:
  trim_video video.mp4 00:00:10 00:00:30
  # Extracts 30 seconds starting at 10 seconds

  trim_video video.mp4 10 30 clip.mp4
  # Same as above using seconds, saves to clip.mp4
EOF
        [ "$1" = "-h" ] || [ "$1" = "--help" ] && return 0 || return 1
    fi

    if ! has ffmpeg; then
        error "ffmpeg not found"
        return 1
    fi

    local input="$1"
    local start="$2"
    local duration="$3"
    local output="${4:-${input%.*}_trimmed.${input##*.}}"

    if [ ! -f "$input" ]; then
        error "Input file not found: $input"
        return 1
    fi

    info "Trimming video from $start for $duration..."
    if ffmpeg -ss "$start" -i "$input" -t "$duration" -c copy -avoid_negative_ts make_zero "$output" 2>&1 | grep -q "error"; then
        error "Trim failed"
        return 1
    fi

    completed "Trimmed video saved to: $output"
}

concat_videos() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -lt 3 ]; then
        cat << 'EOF'
Usage: concat_videos <output> <video1> <video2> [video3...]

Concatenate multiple videos into one using ffmpeg concat demuxer.

Arguments:
  <output>   Path to output video file
  <video1>   Path to first input video
  <video2>   Path to second input video
  [video3..] Additional input videos (optional)

Processing:
  - Uses stream copy (no re-encoding) for fast processing
  - Videos must have the same codec, resolution, and frame rate

Requirements:
  - ffmpeg must be installed

Example:
  concat_videos merged.mp4 video1.mp4 video2.mp4 video3.mp4
  # Merges three videos into one
EOF
        [ "$1" = "-h" ] || [ "$1" = "--help" ] && return 0 || return 1
    fi

    if ! has ffmpeg; then
        error "ffmpeg not found"
        return 1
    fi

    local output="$1"
    shift

    # Validate all input files exist
    for video in "$@"; do
        if [ ! -f "$video" ]; then
            error "Input file not found: $video"
            return 1
        fi
    done

    local concat_file=$(mktemp)
    for video in "$@"; do
        echo "file '$(realpath "$video")'" >> "$concat_file"
    done

    info "Concatenating $# videos..."
    if ffmpeg -f concat -safe 0 -i "$concat_file" -c copy "$output" 2>&1 | grep -q "error"; then
        rm "$concat_file"
        error "Concatenation failed"
        return 1
    fi

    rm "$concat_file"
    completed "Created: $output"
}

insert_image() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -lt 3 ]; then
        cat << 'EOF'
Usage: insert_image <video> <image> <duration> [position] [output]

Insert a still image (displayed for N seconds) before or after a video clip.

Arguments:
  <video>      Path to input video file
  <image>      Path to image file (png, jpg, etc.)
  <duration>   How long to display the image (seconds)
  [position]   "before" (default) or "after"
  [output]     Path to output file (default: <video>_with_image.<ext>)

Processing:
  - Probes original video for resolution, fps, and audio presence
  - Generates a temp video from the image matching those properties
  - Concatenates using the concat demuxer (no re-encoding of main video)
  - Handles aspect ratio mismatches by scaling and padding the image

Requirements:
  - ffmpeg and ffprobe must be installed

Examples:
  insert_image video.mp4 logo.png 3
  # Shows logo.png for 3 seconds, then plays video.mp4

  insert_image video.mp4 title.jpg 5 after result.mp4
  # Plays video.mp4, then shows title.jpg for 5 seconds
EOF
        [ "$1" = "-h" ] || [ "$1" = "--help" ] && return 0 || return 1
    fi

    if ! has ffmpeg || ! has ffprobe; then
        error "ffmpeg and ffprobe are required"
        return 1
    fi

    local video="$1"
    local image="$2"
    local duration="$3"
    local position="${4:-before}"
    local output="${5:-${video%.*}_with_image.${video##*.}}"

    if [ ! -f "$video" ]; then
        error "Video file not found: $video"
        return 1
    fi

    if [ ! -f "$image" ]; then
        error "Image file not found: $image"
        return 1
    fi

    if [ "$position" != "before" ] && [ "$position" != "after" ]; then
        error "Position must be 'before' or 'after', got: $position"
        return 1
    fi

    # Probe the original video for properties
    local width height fps has_audio
    width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$video")
    height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$video")
    fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$video")
    has_audio=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_type -of csv=p=0 "$video" 2>/dev/null)

    if [ -z "$width" ] || [ -z "$height" ] || [ -z "$fps" ]; then
        error "Failed to probe video properties"
        return 1
    fi

    # Create temp directory and ensure cleanup
    local tmpdir
    tmpdir=$(mktemp -d)
    trap "rm -rf '$tmpdir'" EXIT

    local img_video="$tmpdir/image_clip.mp4"

    info "Generating image clip (${width}x${height}, ${fps} fps, ${duration}s)..."

    if [ -n "$has_audio" ]; then
        # Generate image video with silent audio
        ffmpeg -y -loop 1 -i "$image" -f lavfi -i anullsrc=r=44100:cl=stereo \
            -vf "scale=${width}:${height}:force_original_aspect_ratio=decrease,pad=${width}:${height}:(ow-iw)/2:(oh-ih)/2,setsar=1" \
            -c:v libx264 -pix_fmt yuv420p -r "$fps" \
            -c:a aac -shortest -t "$duration" \
            "$img_video" 2>/dev/null
    else
        # Generate image video without audio
        ffmpeg -y -loop 1 -i "$image" \
            -vf "scale=${width}:${height}:force_original_aspect_ratio=decrease,pad=${width}:${height}:(ow-iw)/2:(oh-ih)/2,setsar=1" \
            -c:v libx264 -pix_fmt yuv420p -r "$fps" \
            -t "$duration" \
            "$img_video" 2>/dev/null
    fi

    if [ ! -f "$img_video" ]; then
        error "Failed to generate image clip"
        rm -rf "$tmpdir"
        trap - EXIT
        return 1
    fi

    # Build concat file based on position
    local concat_file="$tmpdir/concat.txt"
    if [ "$position" = "before" ]; then
        echo "file '$(realpath "$img_video")'" > "$concat_file"
        echo "file '$(realpath "$video")'" >> "$concat_file"
    else
        echo "file '$(realpath "$video")'" > "$concat_file"
        echo "file '$(realpath "$img_video")'" >> "$concat_file"
    fi

    info "Concatenating ($position video)..."
    if ! ffmpeg -y -f concat -safe 0 -i "$concat_file" -c copy "$output" 2>/dev/null; then
        error "Concatenation failed"
        rm -rf "$tmpdir"
        trap - EXIT
        return 1
    fi

    rm -rf "$tmpdir"
    trap - EXIT
    completed "Created: $output (image $position video)"
}

speedup_video() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -lt 1 ]; then
        cat << 'EOF'
Usage: speedup_video <input> [factor=2.0] [output]

Speed up a video by a given factor using ffmpeg.

Arguments:
  <input>   Path to input video file
  [factor]  Speed multiplier (default: 2.0, must be > 0)
  [output]  Path to output file (default: <input>_speedup.<ext>)

Details:
  - Video speed uses the setpts filter (PTS/factor)
  - Audio speed uses atempo filter (chained for factors > 2.0,
    since atempo only supports 0.5-2.0 per instance)
  - Factors < 0.5 also chain atempo filters accordingly

Requirements:
  - ffmpeg must be installed

Examples:
  speedup_video video.mp4
  # Creates video_speedup.mp4 at 2x speed

  speedup_video video.mp4 4
  # Creates video_speedup.mp4 at 4x speed

  speedup_video video.mp4 1.5 fast.mp4
  # Creates fast.mp4 at 1.5x speed
EOF
        [ "$1" = "-h" ] || [ "$1" = "--help" ] && return 0 || return 1
    fi

    if ! has ffmpeg; then
        error "ffmpeg not found"
        return 1
    fi

    local input="$1"
    local factor="${2:-2.0}"
    local ext="${input##*.}"
    local base="${input%.*}"
    local output="${3:-${base}_speedup.${ext}}"

    if [ ! -f "$input" ]; then
        error "Input file not found: $input"
        return 1
    fi

    # Build atempo filter chain (each atempo limited to 0.5-2.0 range)
    local atempo_filter=""
    local remaining="$factor"
    while (( $(echo "$remaining > 2.0" | bc -l) )); do
        if [ -z "$atempo_filter" ]; then
            atempo_filter="atempo=2.0"
        else
            atempo_filter="${atempo_filter},atempo=2.0"
        fi
        remaining=$(echo "$remaining / 2.0" | bc -l)
    done
    while (( $(echo "$remaining < 0.5" | bc -l) )); do
        if [ -z "$atempo_filter" ]; then
            atempo_filter="atempo=0.5"
        else
            atempo_filter="${atempo_filter},atempo=0.5"
        fi
        remaining=$(echo "$remaining / 0.5" | bc -l)
    done
    if [ -z "$atempo_filter" ]; then
        atempo_filter="atempo=${remaining}"
    else
        atempo_filter="${atempo_filter},atempo=${remaining}"
    fi

    local video_filter="setpts=PTS/${factor}"

    info "Speeding up video by ${factor}x..."
    if ! ffmpeg -i "$input" -filter:v "$video_filter" -filter:a "$atempo_filter" -y "$output" 2>/dev/null; then
        error "Speed up failed"
        return 1
    fi

    completed "Created: $output"
}

compress_video() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -lt 1 ]; then
        cat << 'EOF'
Usage: compress_video <input> [crf=28] [output]

Compress video with adjustable quality control.

Arguments:
  <input>   Path to input video file
  [crf]     Constant Rate Factor, 0-51 (default: 28)
  [output]  Path to output file (default: <input>_compressed.<same-format>)

CRF quality guide:
  0-17   Visually lossless (very large files)
  18     Visually lossless for most content
  23     Default (good quality, reasonable size)
  28     Smaller file, acceptable quality
  35+    Poor quality

Encoding settings:
  - MP4/default output: H.264 (libx264), preset medium, AAC at 128k
  - AVI output: MPEG-4, MP3 at 128k
  - AVI output maps the CRF value to an AVI qscale internally

Requirements:
  - ffmpeg must be installed

Examples:
  compress_video video.mp4
  # Compresses with CRF 28

  compress_video video.mp4 23 output.mp4
  # Compresses with CRF 23 (higher quality)

  compress_video clip.avi
  # Compresses clip.avi and saves as clip_compressed.avi
EOF
        [ "$1" = "-h" ] || [ "$1" = "--help" ] && return 0 || return 1
    fi

    if ! has ffmpeg; then
        error "ffmpeg not found"
        return 1
    fi

    local input="$1"
    local crf="${2:-28}"
    local output="${3:-${input%.*}_compressed.${input##*.}}"
    local output_ext="${output##*.}"
    output_ext="${output_ext:l}"

    if [ ! -f "$input" ]; then
        error "Input file not found: $input"
        return 1
    fi

    # Validate CRF range
    if [ "$crf" -lt 0 ] || [ "$crf" -gt 51 ]; then
        error "CRF must be between 0 and 51"
        return 1
    fi

    case "$output_ext" in
        avi)
            local qscale=$((1 + (crf * 30 / 51)))
            info "Compressing AVI with CRF=$crf (qscale=$qscale)..."
            if ffmpeg -i "$input" -c:v mpeg4 -qscale:v "$qscale" -c:a libmp3lame -b:a 128k "$output" 2>&1 | grep -qi "error"; then
                error "Compression failed"
                return 1
            fi
            ;;
        *)
            info "Compressing video with CRF=$crf..."
            if ffmpeg -i "$input" -c:v libx264 -crf "$crf" -preset medium -c:a aac -b:a 128k "$output" 2>&1 | grep -qi "error"; then
                error "Compression failed"
                return 1
            fi
            ;;
    esac

    local orig_size=$(du -h "$input" | cut -f1)
    local new_size=$(du -h "$output" | cut -f1)
    completed "Compressed: $orig_size → $new_size ($output)"
}
