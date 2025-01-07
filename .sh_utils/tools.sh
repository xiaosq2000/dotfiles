#!/usr/env/bin bash
auto_conda() {
	local autoenv_zsh_content='has() {
    command -v "$1" 1>/dev/null 2>&1
}
BOLD="$(tput bold 2>/dev/null || printf '')"
YELLOW="$(tput setaf 3 2>/dev/null || printf '')"
RESET="$(tput sgr0 2>/dev/null || printf '')"
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
BOLD="$(tput bold 2>/dev/null || printf '')"
YELLOW="$(tput setaf 3 2>/dev/null || printf '')"
RESET="$(tput sgr0 2>/dev/null || printf '')"
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

webp2png() {
	if has dwebp; then
		dwebp -i $1.webp -o $1.png
	else
		error "dwebp not found."
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
		ffmpeg -i $1.mp4 -vframes 1 $1.png
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
