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
FZF_VERSION=$(curl -s "https://api.github.com/repos/junegunn/fzf/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
info "Installing the latest fzf ($FZF_VERSION)"
if [ -d "$HOME/.fzf" ]; then
	info "Deleting ~/.fzf"
	rm -rf "$HOME/.fzf"
fi
git clone --depth=1 https://github.com/junegunn/fzf.git $HOME/.fzf 1>/dev/null 2>&1
cd $HOME/.fzf
${HOME}/.fzf/install --key-bindings --completion --no-update-rc --xdg 1>/dev/null 2>&1
if [ $? -eq 0 ]; then
	source $HOME/.fzf.bash
	completed "fzf version: $(fzf --version | cut -d' ' -f1)"
else
	error "Failed to install fzf"
	exit 1
fi
