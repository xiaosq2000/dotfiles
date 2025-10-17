#!/bin/bash

set -euo pipefail

# Source the UI library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/ui.sh"

header "Starship Installation - https://starship.rs/"

step "Detecting system information"

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

info "Detected OS: $OS, Architecture: $ARCH"
success "System detection complete"

step "Downloading and installing Starship"

# Create bin directory if it doesn't exist
mkdir -p ~/.local/bin

# Download and install starship
# Unset ZSH_VERSION to avoid potential issues with the install script
if (unset ZSH_VERSION && curl -fsSL https://starship.rs/install.sh | sh -s -- --yes -b ~/.local/bin); then
    success "Starship downloaded and installed"
else
    error "Failed to install Starship"
    exit 1
fi

step "Verifying installation"

# Get version information
if [ -x ~/.local/bin/starship ]; then
    VERSION=$(~/.local/bin/starship --version | head -n1)
    info "Version: $VERSION"
    success "Installation verified"
else
    error "Starship binary not found or not executable"
    exit 1
fi

footer "Starship installed successfully!"
info "Make sure ~/.local/bin is in your PATH"
