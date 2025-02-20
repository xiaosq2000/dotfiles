#!/usr/env/bin zsh
auto_conda() {
	local autoenv_zsh_content='has() {
    command -v "$1" 1>/dev/null 2>&1
}
BOLD="$(tput bold 2>/dev/null || printf "")"
YELLOW="$(tput setaf 3 2>/dev/null || printf "")"
RESET="$(tput sgr0 2>/dev/null || printf "")"
warning() {
    printf "%s\n" "${BOLD}${YELLOW}WARNING:${RESET} $*"
}
if has micromamba; then
    if [[ $(micromamba env list | grep "${environment_name}") ]]; then
        warning "Activating micormamba virtual environment ${BOLD}\"${environment_name}\"${RESET}"
        micromamba activate "${environment_name}"
    fi
fi'
	local autoenv_leave_zsh_content='has() {
    command -v "$1" 1>/dev/null 2>&1
}
BOLD="$(tput bold 2>/dev/null || printf "")"
YELLOW="$(tput setaf 3 2>/dev/null || printf "")"
RESET="$(tput sgr0 2>/dev/null || printf "")"
warning() {
    printf "%s\n" "${BOLD}${YELLOW}WARNING:${RESET} $*"
}
if has micromamba; then
    warning "Deactivating the conda environment."
    micromamba deactivate
fi'
	echo "$autoenv_zsh_content" >.autoenv.zsh
	sed -i "1i environment_name=$1" .autoenv.zsh
	echo "$autoenv_leave_zsh_content" >.autoenv_leave.zsh
}

command_with_email_notification() {
	if [ $# -lt 1 ] || [ $# -gt 3 ]; then
		echo "Usage: command_with_email_notification <command> [directory] [email]"
		echo "Executes the given command in the specified directory (defaults to current directory)"
		echo "and sends an email notification with the status and duration."
		echo "If email is not provided, it will be read from the Git global user configuration."
		return 1
	fi

	local cmd="$1"
	local directory="${2:-.}"
	local email="${3:-$(git config --global user.email)}"

	if [ -z "$email" ]; then
		echo "Email not provided and not found in Git global user configuration."
		return 1
	fi

	local original_dir=$(pwd)
	cd "$directory" || {
		echo "Failed to change to directory: $directory"
		return 1
	}

	local start_time=$(date +%s)
	eval "$cmd"
	local exit_status=$?
	local end_time=$(date +%s)
	local duration=$((end_time - start_time))

	local cmd_status="Success"
	[ $exit_status -ne 0 ] && cmd_status="Failure"

	local subject="Command Execution Notification"
	local body="
<html>
    <head>
        <style>
            body {
                font-family: Arial, sans-serif;
                font-size: 12px;
            }
            .label {
                font-weight: bold;
            }
        </style>
    </head>
    <body>
    <p><span class="label">Status:</span> $cmd_status</p>
    <p><span class="label">Command:</span> $cmd</p>
    <p><span class="label">Duration:</span> $duration seconds</p>
    <p><span class="label">Directory:</span> $(pwd)</p>
    <p><span class="label">Exit Status:</span> $exit_status</p>
    </body>
</html>
"

	echo "Subject: $subject" >email.txt
	echo "Content-Type: text/html; charset=UTF-8" >>email.txt
	echo "MIME-Version: 1.0" >>email.txt
	echo "" >>email.txt
	echo "$body" >>email.txt

	msmtp -a default "$email" <email.txt
	rm email.txt

	cd "$original_dir" || {
		echo "Failed to restore original directory: $original_dir"
		return 1
	}
}

svg2pdf() {
	if has inkscape; then
		inkscape $1.svg -o $1.pdf
	else
		error "inkscape not found."
	fi
}

svg2png() {
	if has convert; then
		if [ $# -ne 1 ]; then
			error "Usage: svg2png <video-path-w/o-ext>"
			return 1
		fi
		local input="$1.svg"
		local output="$1.png"

		if [ ! -f "$input" ]; then
			error "Input file '$input' not found"
			return 1
		fi

        # density: Sets the DPI (dots per inch) resolution. Higher values like 300 or 600 give better quality
        # quality: Sets maximum quality for the output (ranges from 0-100)
        # background none: Preserves transparency
        # define png:compression-level=9: Maximum PNG compression while remaining lossless
        convert -density 600 -background none $input -quality 100 -define png:compression-level=9 $output

		if [ $? -eq 0 ]; then
			completed "Successfully converted $input to $output"
			return 0
		else
			error "Conversion failed"
			return 1
		fi
	else
		error "convert not found."
		return 1
	fi
}

webp2png() {
	if ! has dwebp; then
		error "dwebp not found."
        return 1
	fi
    dwebp $1.webp -o $1.png
    if [ $? -eq 0 ]; then
        completed "Successfully converted $1.webp to $1.png"
    fi
}

webm2mp4() {
	if has ffmpeg; then
		ffmpeg -fflags +genpts -i $1.webm -r ${2:-24} $1.mp4
	else
		error "ffmpeg not found."
	fi
}

gif2mp4() {
	if has ffmpeg; then
		ffmpeg -i $1.gif -movflags faststart -pix_fmt yuv420p -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" $1.mp4
	else
		error "ffmpeg not found."
	fi
}

mp42png() {
	if has ffmpeg; then
		local frame=${2:-0} # Default to first frame (0) if not specified
		ffmpeg -i $1.mp4 -vf "select=eq(n\,$frame)" -vframes 1 $1.png
	else
		error "ffmpeg not found."
	fi
}

compress_pdf() {
	# ref: https://askubuntu.com/a/256449
	if [[ ! "$#" -eq 2 ]]; then
		error "Usage: compress_pdf INPUT_FILE OUTPUT_FILE"
	elif has gs; then
		gs -sDEVICE=pdfwrite \
			-dCompatibilityLevel=1.4 \
			-dNOPAUSE \
			-dQUIET \
			-dBATCH \
			-dPDFSETTINGS=/printer \
			-sOutputFile=$2 \
			$1
	fi
}

mp3mp42mp4() {
	# Function to combine an MP3 audio file with an MP4 video file
	# Usage: mp3mp42mp4 <input_audio.mp3> <input_video.mp4> <output.mp4> [options]
	# Options:
	#   -f, --force       : Overwrite output file if it exists
	#   -q, --quality N   : Audio quality (32k-320k, default: 192k)
	#   -v, --volume N    : Adjust audio volume (0.0-10.0, default: 1.0)

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

avi2mp4() {
	if has ffmpeg; then
		if [ $# -ne 1 ]; then
			error "Usage: avi2mp4 <video-path-w/o-ext>"
			return 1
		fi

		local input="$1.avi"
		local output="$1.mp4"

		# Uses ffmpeg with these settings:
		#    - Video codec: libx264 (H.264)
		#    - Preset: medium (good balance between speed and compression)
		#    - CRF: 23 (good quality with reasonable file size)
		#    - Audio codec: AAC
		#    - Audio bitrate: 128k (good quality for most purposes)
		ffmpeg -i "$input" -c:v libx264 -preset medium -crf 23 -c:a aac -b:a 128k "$output"
	else
		error "ffmpeg not found."
	fi
}

mp42avi() {
	if has ffmpeg; then
		if [ $# -ne 1 ]; then
			error "Usage: mp42avi <video-path-w/o-ext>"
			return 1
		fi
		local input="$1.mp4"
		local output="$1.avi"
		# Uses ffmpeg with these settings:
		#    - Video codec: mpeg4 (standard AVI codec)
		#    - Quality: qscale 3 (good quality)
		#    - Audio codec: mp3
		#    - Audio bitrate: 128k
		ffmpeg -i "$input" -c:v mpeg4 -qscale:v 3 -c:a libmp3lame -b:a 128k "$output"
	else
		error "ffmpeg not found."
	fi
}

jpg2png() {
	if has convert; then
		if [ $# -ne 1 ]; then
			error "Usage: jpg2png <video-path-w/o-ext>"
			return 1
		fi
		local input="$1.jpg"
		local output="$1.png"

		if [ ! -f "$input" ]; then
			error "Input file '$input' not found"
			return 1
		fi

		convert "$input" "$output"

		if [ $? -eq 0 ]; then
			completed "Successfully converted $input to $output"
			return 0
		else
			error "Conversion failed"
			return 1
		fi
	else
		error "convert not found."
		return 1
	fi
}

invert_color() {
    if ! has convert; then
        error "Error: ImageMagick's convert not found"
        return 1
    fi

    if [ $# -ne 2 ]; then
        error "Usage: $0 <input-img-path> <output-img-path>"
        return 1
    fi

    local input="$1"
    local output="$2"

    # -colorspace HSL: Converts the image to HSL color space
    # -channel L: Selects only the Lightness channel for modification
    # -negate: Inverts the selected channel
    # -colorspace sRGB: Converts back to standard RGB color space
    convert $input -colorspace HSL -channel L -negate -colorspace sRGB $output
    return $?
}

transparent_bg() {
    if ! has convert; then
        error "Error: ImageMagick's convert not found"
        return 1
    fi

    if [ $# -ne 2 ]; then
        error "Usage: $0 <input-img-path> <output-img-path>"
        return 1
    fi

    local input="$1"
    local output="$2"
    local fuzz="1%"            # Adjust tolerance as needed
    local original_bg="white"  # e.g. "#FF0000"

    convert "$input" -fuzz "$fuzz" -transparent white "$output"
    return $?
}

# invert_lightness() {
#     if [ $# -ne 1 ]; then
#         echo "Usage: invert_lightness <hex_color>"
#         echo "Example: invert_lightness '#FF0000'"
#         return 1
#     fi
#
#     input_hex=$1
#     r=$(printf "%d" 0x${input_hex:1:2})
#     g=$(printf "%d" 0x${input_hex:3:2})
#     b=$(printf "%d" 0x${input_hex:5:2})
#
#     # Convert RGB to HSL
#     r_norm=$(echo "scale=6; $r / 255" | bc)
#     g_norm=$(echo "scale=6; $g / 255" | bc)
#     b_norm=$(echo "scale=6; $b / 255" | bc)
#
#     max_rgb=$(echo "$r_norm $g_norm $b_norm" | tr ' ' '\n' | sort -n | tail -1)
#     min_rgb=$(echo "$r_norm $g_norm $b_norm" | tr ' ' '\n' | sort -n | head -1)
#
#     # Calculate lightness
#     l=$(echo "scale=6; ($max_rgb + $min_rgb) / 2" | bc)
#
#     # Invert lightness
#     new_l=$(echo "scale=6; 1 - $l" | bc)
#
#     # Keep original hue and saturation, but with new lightness
#     # For simplicity, we'll approximate by scaling RGB values
#     scale=$(echo "scale=6; $new_l / $l" | bc)
#
#     new_r=$(echo "scale=0; $r * $scale / 1" | bc)
#     new_g=$(echo "scale=0; $g * $scale / 1" | bc)
#     new_b=$(echo "scale=0; $b * $scale / 1" | bc)
#
#     # Ensure values are within bounds
#     new_r=$(echo "if ($new_r > 255) 255 else if ($new_r < 0) 0 else $new_r" | bc)
#     new_g=$(echo "if ($new_g > 255) 255 else if ($new_g < 0) 0 else $new_g" | bc)
#     new_b=$(echo "if ($new_b > 255) 255 else if ($new_b < 0) 0 else $new_b" | bc)
#
#     printf "#%02x%02x%02x\n" $new_r $new_g $new_b
# }
