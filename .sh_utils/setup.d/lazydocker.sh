#!/usr/bin/env bash
source ~/.sh_utils/basics.sh
info "Installing the latest lazydocker"
curl -sS https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash 1>/dev/null 2>&1
if [ $? -eq 0 ]; then
	completed "lazydocker version: $($XDG_PREFIX_HOME/bin/lazydocker --version | head -n 1 | cut -d' ' -f2)"
else
	error "Failed to install lazydocker"
    exit 1
fi
