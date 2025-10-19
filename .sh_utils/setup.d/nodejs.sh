#!/usr/bin/env bash
source ~/.sh_utils/lib/ui.sh

export NVM_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/nvm"

step "Installing the latest nvm"
mkdir -p ${NVM_DIR}
(unset ZSH_VERSION && PROFILE=/dev/null bash -c 'wget -qO- "https://github.com/nvm-sh/nvm/raw/master/install.sh" | bash' 1>/dev/null 2>&1)
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
if [ $? -eq 0 ]; then
	success "nvm version: $(nvm --version)"
else
	error "Failed to install nvm"
	rm -rf $NVM_DIR
	exit 1
fi

step "Installing the latest lts node.js"
nvm install --lts node 1>/dev/null 2>&1
if [ $? -eq 0 ]; then
	success "node version: $(node --version)"
else
	error "Failed to install node"
	exit 1
fi

step "Installing tree-sitter-cli"
npm install -g tree-sitter-cli 1>/dev/null 2>&1
if [ $? -eq 0 ]; then
	success "$(tree-sitter --version)"
else
	error "Failed to install tree-sitter-cli"
	exit 1
fi

step "Installing deno"
npm install -g deno 1>/dev/null 2>&1
if [ $? -eq 0 ]; then
	success "$(deno --version | head -n 1)"
else
	error "Failed to install deno"
	exit 1
fi

step "Installing claude code"
npm install -g @anthropic-ai/claude-code 1>/dev/null 2>&1
if [ $? -eq 0 ]; then
	success "$(claude --version)"
else
	error "Failed to install deno"
	exit 1
fi

step "Installing codex"
npm install -g @openai/codex 1>/dev/null 2>&1
if [ $? -eq 0 ]; then
	success "$(codex --version)"
else
	error "Failed to install codex"
	exit 1
fi
