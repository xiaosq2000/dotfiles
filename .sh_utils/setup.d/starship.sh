#!/usr/bin/env bash
source ~/.sh_utils/basics.sh
info "Installing the latest starship"
(unset ZSH_VERSION && wget -qO- https://starship.rs/install.sh | /bin/sh -s -- --yes -b ${XDG_PREFIX_HOME}/bin 1>/dev/null 2>&1)
if [ $? -eq 0 ]; then
	completed "$(starship --version | head -n1)"
else
	error "Failed to install starship"
	exit 1
fi
