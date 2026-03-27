#!/usr/bin/env zsh

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
