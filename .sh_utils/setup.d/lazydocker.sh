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
export XDG_PREFIX_HOME="${XDG_PREFIX_HOME:-$HOME/.local}"

info "Installing the latest lazydocker"
curl -sS https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash 1>/dev/null 2>&1
if [ $? -eq 0 ]; then
	completed "lazydocker version: $($XDG_PREFIX_HOME/bin/lazydocker --version | head -n 1 | cut -d' ' -f2)"
else
	error "Failed to install lazydocker"
    exit 1
fi
