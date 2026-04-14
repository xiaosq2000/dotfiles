#!/usr/bin/env bash
source ~/.sh_utils/lib/ui.sh

export NVM_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/nvm"

refresh_nvm_default_symlink() {
    local default_node_bin default_node_dir

    default_node_bin="$(nvm which default 2>/dev/null)" || return 1
    if [[ ! -x "$default_node_bin" ]]; then
        return 1
    fi

    default_node_dir="$(dirname "$(dirname "$default_node_bin")")"
    ln -sfn "$default_node_dir" "$NVM_DIR/default"
}

step "Installing the latest nvm"
mkdir -p "${NVM_DIR}"
(unset ZSH_VERSION && PROFILE=/dev/null bash -c 'wget -qO- "https://github.com/nvm-sh/nvm/raw/master/install.sh" | bash' 1>/dev/null 2>&1)
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
if [ $? -eq 0 ]; then
    success "nvm version: $(nvm --version)"
else
    error "Failed to install nvm"
    rm -rf "$NVM_DIR"
    exit 1
fi

step "Installing the latest lts node.js"
nvm install --lts 1>/dev/null 2>&1
if [ $? -eq 0 ]; then
    if ! nvm alias default 'lts/*' 1>/dev/null 2>&1; then
        error "Failed to set nvm default alias"
        exit 1
    fi
    if ! nvm use --silent default 1>/dev/null 2>&1; then
        error "Failed to activate the default node version"
        exit 1
    fi
    if ! refresh_nvm_default_symlink; then
        error "Failed to refresh the nvm default symlink"
        exit 1
    fi
    success "node version: $(node --version)"
else
    error "Failed to install node"
    exit 1
fi

step "Installing bw"
npm install -g @bitwarden/cli 1>/dev/null 2>&1
if [ $? -eq 0 ]; then
    success "$(bw --version)"
else
    error "Failed to install bw"
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

step "Installing opencode"
npm install -g opencode-ai 1>/dev/null 2>&1
if [ $? -eq 0 ]; then
    success "$(opencode --version)"
else
    error "Failed to install opencode"
    exit 1
fi
