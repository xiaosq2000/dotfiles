#!/usr/bin/env zsh
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

local glibc_version=$(getconf GNU_LIBC_VERSION | cut -d' ' -f2)
local glibc_num=$(echo "$glibc_version" | awk -F. '{print $1 * 100 + $2}')

local XDG_PREFIX_HOME="$HOME/.local"

if ((glibc_num >= 232)); then
	info "Installing the latest yazi (linux, x86_64, gnu)"
	curl -s "https://api.github.com/repos/sxyazi/yazi/releases/latest" |
		grep 'browser_download_url.*yazi-x86_64-unknown-linux-gnu.zip' |
		cut -d : -f 2,3 |
		tr -d \" |
		wget -qi -
	unzip -qq yazi-x86_64-unknown-linux-gnu.zip
	cp yazi-x86_64-unknown-linux-gnu/ya* $XDG_PREFIX_HOME/bin/
	rm -r yazi-x86_64-unknown-linux-gnu*
else
	info "Building the latest yazi from source."
	YAZI_VERSION=$(curl -s "https://api.github.com/repos/sxyazi/yazi/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
	git clone https://github.com/sxyazi/yazi
	cd yazi
	git checkout $YAZI_VERSION
	cargo build --release --locked
	mv target/release/yazi target/release/ya $XDG_PREFIX_HOME/bin/
	cd ..
	rm -rf yazi
fi

if [ -x "$XDG_PREFIX_HOME/bin/yazi" ]; then
	completed "yazi version: $($XDG_PREFIX_HOME/bin/yazi --version | cut -d' ' -f2)"
else
	error "Failed to install yazi"
    exit 1
fi
