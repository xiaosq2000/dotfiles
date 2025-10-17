#!/bin/bash

set -euo pipefail

# Source the UI library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/ui.sh"

header "Neovim Installation"

step "Detecting system information"

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

# Map architecture names
case "$ARCH" in
    x86_64|amd64)
        ARCH="x86_64"
        ;;
    aarch64|arm64)
        ARCH="arm64"
        ;;
    *)
        error "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Map OS names and construct filename
case "$OS" in
    linux)
        FILENAME="nvim-linux-${ARCH}.tar.gz"
        ;;
    darwin)
        FILENAME="nvim-macos-${ARCH}.tar.gz"
        ;;
    *)
        error "Unsupported OS: $OS"
        exit 1
        ;;
esac

info "Detected OS: $OS, Architecture: $ARCH"
info "Looking for: $FILENAME"
success "System detection complete"

step "Fetching latest Neovim release information"

# Get the latest release info from GitHub API
LATEST_RELEASE=$(curl -s https://api.github.com/repos/neovim/neovim/releases/latest)

# Extract the download URL for the detected platform
DOWNLOAD_URL=$(echo "$LATEST_RELEASE" | jq -r --arg filename "$FILENAME" '.assets[] | select(.name == $filename) | .browser_download_url')

# Extract version for logging
VERSION=$(echo "$LATEST_RELEASE" | jq -r '.tag_name')

# Check if we got a valid download URL
if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "null" ]; then
    error "Could not find download URL for $FILENAME"
    info "Available assets:"
    echo "$LATEST_RELEASE" | jq -r '.assets[].name'
    exit 1
fi

info "Version: $VERSION"
info "Download URL: $DOWNLOAD_URL"
success "Release information retrieved"

step "Downloading Neovim $VERSION"

# Create temporary directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Download the tar.gz file
if curl -L -o "$FILENAME" "$DOWNLOAD_URL" 2>&1 | grep -q "100"; then
    success "Download complete"
else
    success "Download complete"
fi

# Check if download was successful
if [ ! -f "$FILENAME" ]; then
    error "Download failed"
    exit 1
fi

step "Extracting archive"

# Extract the archive
tar -xzf "$FILENAME"
success "Archive extracted"

step "Installing to ~/.local"

# Create ~/.local directories if they don't exist
mkdir -p ~/.local/bin
mkdir -p ~/.local/share
mkdir -p ~/.local/lib

# Determine the extracted directory name (remove .tar.gz extension)
EXTRACTED_DIR="${FILENAME%.tar.gz}"

# Install to ~/.local
cp -r "$EXTRACTED_DIR"/bin/* ~/.local/bin/
cp -r "$EXTRACTED_DIR"/share/* ~/.local/share/
cp -r "$EXTRACTED_DIR"/lib/* ~/.local/lib/

success "Files copied to ~/.local"

step "Cleaning up temporary files"

# Clean up
cd /
rm -rf "$TEMP_DIR"

success "Cleanup complete"

footer "Neovim $VERSION installed successfully!"
info "Make sure ~/.local/bin is in your PATH"
