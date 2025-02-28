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
export XDG_PREFIX_HOME="$HOME/.local"
info "Installing the latest starship"
(unset ZSH_VERSION && wget -qO- https://starship.rs/install.sh | /bin/sh -s -- --yes -b ${XDG_PREFIX_HOME}/bin 1>/dev/null 2>&1)
if [ $? -eq 0 ]; then
	completed "$(starship --version | head -n1)"
else
	error "Failed to install starship"
	exit 1
fi
