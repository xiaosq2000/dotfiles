#!/usr/bin/env zsh

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
