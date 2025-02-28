#!/usr/bin/env bash
BOLD="$(tput bold 2>/dev/null || printf '')"
RED="$(tput setaf 1 2>/dev/null || printf '')"
GREEN="$(tput setaf 2 2>/dev/null || printf '')"
YELLOW="$(tput setaf 3 2>/dev/null || printf '')"
RESET="$(tput sgr0 2>/dev/null || printf '')"
error() {
	printf '%s\n' "${BOLD}${RED}ERROR:${RESET} $*" >&2
}
warning() {
	printf '%s\n' "${BOLD}${YELLOW}WARNING:${RESET} $*"
}
info() {
	printf '%s\n' "${BOLD}${GREEN}INFO:${RESET} $*"
}
completed() {
	printf '%s\n' "${BOLD}${GREEN}✓${RESET} $*"
}
# https://labbots.github.io/google-drive-upload/
info "Installing the latest google-drive-upload"
# Store output in temp file
tmpfile=$(mktemp)
if ! curl --compressed -Ls https://github.com/labbots/google-drive-upload/raw/master/install.sh | sh -s >"$tmpfile" 2>&1; then
	error "Failed to install google-drive-upload"
	rm "$tmpfile"
	exit 1
fi
rm "$tmpfile"
completed "google-drive-upload version: $($HOME/.google-drive-upload/bin/gupload --version | grep '^LATEST_INSTALLED_SHA' | cut -d' ' -f2)"
