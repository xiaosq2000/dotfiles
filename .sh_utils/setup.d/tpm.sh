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
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
if [ -d "${XDG_DATA_HOME}/tmux/plugins/tpm" ]; then
    info "Deleting ${XDG_DATA_HOME}/tmux/plugins/tpm"
    rm -rf "${XDG_DATA_HOME}/tmux/plugins/tpm"
fi 
info "Installing the latest tpm"
git clone --depth 1 https://github.com/tmux-plugins/tpm ${XDG_DATA_HOME}/tmux/plugins/tpm 1>/dev/null 2>&1 
if [ $? -eq 0 ]; then
    completed "tpm version: $(cd ${XDG_DATA_HOME}/tmux/plugins/tpm && git reflog HEAD | head -n 1 | cut -d' ' -f1)"
else
	error "Failed to install tpm"
    exit 1
fi
