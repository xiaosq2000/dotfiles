#!/usr/bin/env bash

# Determine the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UI_LIB="$SCRIPT_DIR/../lib/ui.sh"

# Source the UI library
source "$UI_LIB"

msg_header "ZSH SETUP"

# Install oh-my-zsh if not already installed
ZSH="${ZSH:-${HOME}/.oh-my-zsh}"
if [ -f "$ZSH/oh-my-zsh.sh" ]; then
    msg_info "oh-my-zsh already installed at $ZSH"
else
    msg_step "Installing oh-my-zsh"
    if (unset ZSH; /bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc >/dev/null 2>&1); then
        msg_success "oh-my-zsh installed successfully"
    else
        msg_error "Failed to install oh-my-zsh"
        exit 1
    fi
fi

# Install zsh plugins within oh-my-zsh
ZSH_CUSTOM=${ZSH_CUSTOM:-${ZSH}/custom}

if [ -f "$ZSH/oh-my-zsh.sh" ]; then
msg_step "Installing zsh plugins"

msg_info "Installing conda-zsh-completion..."
if git clone --depth 1 https://github.com/conda-incubator/conda-zsh-completion "${ZSH_CUSTOM}/plugins/conda-zsh-completion" >/dev/null 2>&1; then
    msg_success "conda-zsh-completion installed"
else
    msg_warning "Failed to install conda-zsh-completion (may already exist)"
fi

msg_info "Installing zsh-syntax-highlighting..."
if git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting" >/dev/null 2>&1; then
    msg_success "zsh-syntax-highlighting installed"
else
    msg_warning "Failed to install zsh-syntax-highlighting (may already exist)"
fi

msg_info "Installing zsh-autosuggestions..."
if git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions.git "${ZSH_CUSTOM}/plugins/zsh-autosuggestions" >/dev/null 2>&1; then
    msg_success "zsh-autosuggestions installed"
else
    msg_warning "Failed to install zsh-autosuggestions (may already exist)"
fi

msg_info "Installing zsh-autoenv..."
if git clone --depth 1 https://github.com/Tarrasch/zsh-autoenv "${ZSH_CUSTOM}/plugins/zsh-autoenv" >/dev/null 2>&1; then
    msg_success "zsh-autoenv installed"
else
    msg_warning "Failed to install zsh-autoenv (may already exist)"
fi

msg_info "Installing zsh-vi-mode..."
if git clone --depth 1 https://github.com/jeffreytse/zsh-vi-mode "${ZSH_CUSTOM}/plugins/zsh-vi-mode" >/dev/null 2>&1; then
    msg_success "zsh-vi-mode installed"
else
    msg_warning "Failed to install zsh-vi-mode (may already exist)"
fi

msg_info "Installing fzf-tab..."
if git clone --depth 1 https://github.com/Aloxaf/fzf-tab "${ZSH_CUSTOM}/plugins/fzf-tab" >/dev/null 2>&1; then
    msg_success "fzf-tab installed"
else
    msg_warning "Failed to install fzf-tab (may already exist)"
fi
else
    msg_warning "oh-my-zsh not installed; skipping zsh plugin installation"
fi

msg_footer "ZSH SETUP COMPLETE!"
