#!/usr/bin/env zsh

source ~/.sh_utils/basics.sh

command_with_email_notification() {
	# Show help for -h, --help, or wrong usage
	if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -lt 1 ] || [ $# -gt 3 ]; then
		cat << 'EOF'
Usage: command_with_email_notification <command> [directory] [email]

Executes the given command in the specified directory and sends an email
notification with the status and duration upon completion.

Arguments:
  <command>    Command to execute (quoted if it has spaces)
  [directory]  Directory to run the command in (default: current directory)
  [email]      Email address to notify (default: git config --global user.email)

Requirements:
  - msmtp must be installed and configured

Example:
  command_with_email_notification "make build" ~/project user@example.com
EOF
		[ "$1" = "-h" ] || [ "$1" = "--help" ] && return 0 || return 1
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

    if ! has msmtp; then
        echo "Error: msmtp is not found."
        echo "Please Install and configure msmtp."
        rm email.txt
        cd "$original_dir" || return 1
        return 1
    fi

	msmtp -a default "$email" <email.txt
	rm email.txt

	cd "$original_dir" || {
		echo "Failed to restore original directory: $original_dir"
		return 1
	}
}

svg2pdf() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -ne 1 ]; then
		cat << 'EOF'
Usage: svg2pdf <file-without-extension>

Convert an SVG file to PDF using Inkscape.

Arguments:
  <file-without-extension>  Base name of the file (e.g., "image" for "image.svg")

Requirements:
  - inkscape must be installed

Example:
  svg2pdf mylogo
  # Converts mylogo.svg to mylogo.pdf
EOF
		[ "$1" = "-h" ] || [ "$1" = "--help" ] && return 0 || return 1
	fi

	if has inkscape; then
		inkscape $1.svg -o $1.pdf
	else
		error "inkscape not found."
	fi
}

svg2png() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -ne 1 ]; then
		cat << 'EOF'
Usage: svg2png <file-without-extension>

Convert an SVG file to PNG with high quality using ImageMagick convert.

Arguments:
  <file-without-extension>  Base name of the file (e.g., "image" for "image.svg")

Quality settings:
  - Density: 600 DPI for high resolution
  - Quality: 100 (maximum)
  - Compression: Level 9 (maximum lossless compression)
  - Background: Preserves transparency

Requirements:
  - ImageMagick's convert must be installed

Example:
  svg2png diagram
  # Converts diagram.svg to diagram.png with high quality
EOF
		[ "$1" = "-h" ] || [ "$1" = "--help" ] && return 0 || return 1
	fi

	if has convert; then
		local input="$1.svg"
		local output="$1.png"

		if [ ! -f "$input" ]; then
			error "Input file '$input' not found"
			return 1
		fi

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
	if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -ne 1 ]; then
		cat << 'EOF'
Usage: webp2png <file-without-extension>

Convert a WebP image to PNG using dwebp.

Arguments:
  <file-without-extension>  Base name of the file (e.g., "image" for "image.webp")

Requirements:
  - dwebp (WebP tools) must be installed

Example:
  webp2png photo
  # Converts photo.webp to photo.png
EOF
		[ "$1" = "-h" ] || [ "$1" = "--help" ] && return 0 || return 1
	fi

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

compress_pdf() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -ne 2 ]; then
		cat << 'EOF'
Usage: compress_pdf INPUT_FILE OUTPUT_FILE

Compress a PDF file using Ghostscript with printer-quality settings.

Arguments:
  INPUT_FILE   Path to the input PDF file
  OUTPUT_FILE  Path to the output compressed PDF file

Compression settings:
  - PDFSETTINGS: /printer (good quality, reasonable file size)
  - Compatibility: PDF 1.4

Requirements:
  - Ghostscript (gs) must be installed

Reference:
  https://askubuntu.com/a/256449

Example:
  compress_pdf large.pdf small.pdf
  # Compresses large.pdf and saves as small.pdf
EOF
		[ "$1" = "-h" ] || [ "$1" = "--help" ] && return 0 || return 1
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

concat_pdfs() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -lt 3 ]; then
		cat << 'EOF'
Usage: concat_pdfs <output.pdf> <input1.pdf> <input2.pdf> [input3.pdf...]

Concatenate multiple PDF files into one using Ghostscript.

Arguments:
  <output.pdf>   Path to output PDF file
  <input1.pdf>   First PDF to include
  <input2.pdf>   Second PDF to include
  [input3.pdf..] Additional PDFs (optional)

PDFs are merged in the order specified.

Requirements:
  - Ghostscript (gs) must be installed

Examples:
  concat_pdfs merged.pdf chapter1.pdf chapter2.pdf chapter3.pdf
  # Merges three PDFs into merged.pdf
EOF
		[ "$1" = "-h" ] || [ "$1" = "--help" ] && return 0 || return 1
	fi

	if ! has gs; then
		error "Ghostscript (gs) not found."
		return 1
	fi

	local output="$1"
	shift

	for file in "$@"; do
		if [ ! -f "$file" ]; then
			error "Input file not found: $file"
			return 1
		fi
	done

	info "Concatenating $# PDFs..."
	if gs -dBATCH -dNOPAUSE -dQUIET -sDEVICE=pdfwrite -sOutputFile="$output" "$@"; then
		completed "Created: $output ($# files merged)"
		return 0
	else
		error "PDF concatenation failed"
		return 1
	fi
}

pdf2img() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		cat << 'EOF'
Usage: pdf2img [options] <file-without-extension>

Convert a PDF to a PNG or JPG image using ImageMagick convert.

Options:
  -f, --format FORMAT   Output format: png (default) or jpg
  -d, --density DPI     Rasterization DPI (default: 300)
  -q, --quality N       Output quality 1-100 (default: 100 for png, 92 for jpg)
  -c, --concat          Vertically concatenate all pages into one tall image

Arguments:
  <file-without-extension>  Base name of the file (e.g., "document" for "document.pdf")

Quality settings:
  - Density is applied before input for proper rasterization
  - Background: white (transparency flattened)
  - PNG compression: level 9 (maximum lossless)

Requirements:
  - ImageMagick's convert must be installed

Examples:
  pdf2img document
  # Converts document.pdf to document.png at 300 DPI

  pdf2img -f jpg document
  # Converts document.pdf to document.jpg

  pdf2img -d 600 -q 100 document
  # High-resolution 600 DPI conversion

  pdf2img -c multi_page_doc
  # Concatenates all pages of multi_page_doc.pdf into one tall image
EOF
		return 0
	fi

	local format="png"
	local density=300
	local quality=""
	local concat=false

	# Parse named arguments
	while [[ $# -gt 0 ]]; do
		case $1 in
		-f | --format)
			format="$2"
			shift 2
			;;
		-d | --density)
			density="$2"
			shift 2
			;;
		-q | --quality)
			quality="$2"
			shift 2
			;;
		-c | --concat)
			concat=true
			shift
			;;
		*)
			break
			;;
		esac
	done

	if [ $# -ne 1 ]; then
		error "Missing required argument: <file-without-extension>"
		echo "Usage: pdf2img [options] <file-without-extension>" >&2
		return 1
	fi

	if [ "$format" != "png" ] && [ "$format" != "jpg" ]; then
		error "Unsupported format '$format'. Use 'png' or 'jpg'."
		return 1
	fi

	# Set default quality based on format
	if [ -z "$quality" ]; then
		if [ "$format" = "png" ]; then
			quality=100
		else
			quality=92
		fi
	fi

	if has convert; then
		local input="$1.pdf"
		local output="$1.$format"

		if [ ! -f "$input" ]; then
			error "Input file '$input' not found"
			return 1
		fi

		info "Converting $input to $output (${density} DPI, quality ${quality})..."

		local format_opts=""
		if [ "$format" = "png" ]; then
			format_opts="-define png:compression-level=9"
		fi

		if [ "$concat" = true ]; then
			convert -density "$density" "$input" \
				-background white -alpha remove -alpha off \
				-quality "$quality" $format_opts -append "$output"
		else
			convert -density "$density" "$input" \
				-background white -alpha remove -alpha off \
				-quality "$quality" $format_opts "$output"
		fi

		if [ $? -eq 0 ]; then
			local msg="Successfully converted $input to $output"
			[ "$concat" = true ] && msg="$msg (concatenated)"
			completed "$msg"
			return 0
		else
			error "Conversion failed"
			return 1
		fi
	else
		error "convert not found. Install ImageMagick."
		return 1
	fi
}

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

jpg2png() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -ne 1 ]; then
		cat << 'EOF'
Usage: jpg2png <image-path-w/o-ext>

Convert JPG to PNG using ImageMagick convert.

Arguments:
  <image-path-w/o-ext>  Base name of the file (e.g., "photo" for "photo.jpg")

Requirements:
  - ImageMagick's convert must be installed

Example:
  jpg2png photo
  # Converts photo.jpg to photo.png
EOF
		[ "$1" = "-h" ] || [ "$1" = "--help" ] && return 0 || return 1
	fi

	if has convert; then
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

jpeg2png() {
	if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -ne 1 ]; then
		cat << 'EOF'
Usage: jpeg2png <image-path-w/o-ext>

Convert JPEG to PNG using ImageMagick convert.

Arguments:
  <image-path-w/o-ext>  Base name of the file (e.g., "photo" for "photo.jpeg")

Requirements:
  - ImageMagick's convert must be installed

Example:
  jpeg2png photo
  # Converts photo.jpeg to photo.png
EOF
		[ "$1" = "-h" ] || [ "$1" = "--help" ] && return 0 || return 1
	fi

	if has convert; then
		local input="$1.jpeg"
		local output="$1.png"

		if [ ! -f "$input" ]; then
		e	error "Input file '$input' not found"
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
