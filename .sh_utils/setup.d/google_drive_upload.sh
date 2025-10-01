#!/usr/bin/env bash
source ~/.sh_utils/basics.sh
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
