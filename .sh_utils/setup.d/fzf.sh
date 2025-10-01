#!/usr/bin/env bash

# Determine the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UI_LIB="$SCRIPT_DIR/../lib/ui.sh"

# Source the UI library
if [ -f "$UI_LIB" ]; then
    source "$UI_LIB"
else
    echo "ERROR: UI library not found at $UI_LIB"
    exit 1
fi

set -e # Exit immediately if a command exits with a non-zero status

msg_header "FZF INSTALLATION"

# Get the latest fzf version
msg_step "Fetching latest fzf version"
FZF_VERSION=$(curl -s "https://api.github.com/repos/junegunn/fzf/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
if [ -z "$FZF_VERSION" ]; then
    msg_error "Failed to fetch fzf version"
    exit 1
fi
msg_success "Latest fzf version: $FZF_VERSION"

# Remove existing fzf installation if present
if [ -d "$HOME/.fzf" ]; then
    msg_step "Removing existing fzf installation"
    rm -rf "$HOME/.fzf"
    msg_success "Existing installation removed"
fi

# Clone fzf repository
msg_step "Cloning fzf repository"
if git clone --depth=1 https://github.com/junegunn/fzf.git "$HOME/.fzf" >/dev/null 2>&1; then
    msg_success "Repository cloned successfully"
else
    msg_error "Failed to clone fzf repository"
    exit 1
fi

# Install fzf
msg_step "Installing fzf"
cd "$HOME/.fzf"
if "${HOME}/.fzf/install" --all --no-update-rc --xdg >/dev/null 2>&1; then
    msg_success "fzf installed successfully"
else
    msg_error "Failed to install fzf"
    exit 1
fi

# Source fzf configuration
msg_step "Loading fzf configuration"
FZF_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fzf"

# Detect current shell and pick matching fzf config
if [ -n "$BASH_VERSION" ]; then
    FZF_CONFIG="$FZF_CONFIG_DIR/fzf.bash"
elif [ -n "$ZSH_VERSION" ]; then
    FZF_CONFIG="$FZF_CONFIG_DIR/fzf.zsh"
else
    FZF_CONFIG=""
fi

if [ -n "$FZF_CONFIG" ] && [ -f "$FZF_CONFIG" ]; then
    set +e
    # shellcheck disable=SC1090
    source "$FZF_CONFIG"
    STATUS=$?
    set -e
    if [ $STATUS -eq 0 ]; then
        msg_success "fzf configuration loaded from $FZF_CONFIG"
    else
        msg_warning "Failed to source fzf configuration from $FZF_CONFIG (exit $STATUS)"
    fi
else
    if [ -z "$FZF_CONFIG" ]; then
        msg_warning "Unknown shell; skipping fzf config sourcing"
    else
        msg_warning "fzf configuration file not found at $FZF_CONFIG"
    fi
fi

# Verify installation
msg_step "Verifying installation"
if command -v fzf >/dev/null 2>&1; then
    INSTALLED_VERSION=$(fzf --version | cut -d' ' -f1)
    msg_success "fzf version: $INSTALLED_VERSION"
else
    msg_error "fzf command not found after installation"
    exit 1
fi

msg_footer "FZF INSTALLATION COMPLETE!"
