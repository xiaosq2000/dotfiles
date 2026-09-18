#!/usr/bin/env zsh

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
