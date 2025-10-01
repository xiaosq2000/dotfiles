#!/bin/bash

set -euo pipefail

# Source the UI library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/ui.sh"

msg_header "Starship Installation - https://starship.rs/"

msg_step "Detecting system information"

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

msg_info "Detected OS: $OS, Architecture: $ARCH"
msg_success "System detection complete"

msg_step "Downloading and installing Starship"

# Create bin directory if it doesn't exist
mkdir -p ~/.local/bin

# Download and install starship
# Unset ZSH_VERSION to avoid potential issues with the install script
if (unset ZSH_VERSION && curl -fsSL https://starship.rs/install.sh | sh -s -- --yes -b ~/.local/bin); then
    msg_success "Starship downloaded and installed"
else
    msg_error "Failed to install Starship"
    exit 1
fi

msg_step "Verifying installation"

# Get version information
if [ -x ~/.local/bin/starship ]; then
    VERSION=$(~/.local/bin/starship --version | head -n1)
    msg_info "Version: $VERSION"
    msg_success "Installation verified"
else
    msg_error "Starship binary not found or not executable"
    exit 1
fi

msg_footer "Starship installed successfully!"
msg_info "Make sure ~/.local/bin is in your PATH"
