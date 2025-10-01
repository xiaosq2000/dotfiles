#!/usr/bin/env bash
source ~/.sh_utils/lib/ui.sh

export NVM_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/nvm"

msg_step "Installing the latest nvm"
mkdir -p ${NVM_DIR}
(unset ZSH_VERSION && PROFILE=/dev/null bash -c 'wget -qO- "https://github.com/nvm-sh/nvm/raw/master/install.sh" | bash' 1>/dev/null 2>&1)
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
if [ $? -eq 0 ]; then
	msg_success "nvm version: $(nvm --version)"
else
	msg_error "Failed to install nvm"
	rm -rf $NVM_DIR
	exit 1
fi

msg_step "Installing the latest lts node.js"
nvm install --lts node 1>/dev/null 2>&1
if [ $? -eq 0 ]; then
	msg_success "node version: $(node --version)"
else
	msg_error "Failed to install node"
	exit 1
fi

msg_step "Installing tree-sitter-cli"
npm install -g tree-sitter-cli 1>/dev/null 2>&1
if [ $? -eq 0 ]; then
	msg_success "$(tree-sitter --version)"
else
	msg_error "Failed to install tree-sitter"
	exit 1
fi
