#!/bin/bash

set -euo pipefail

# Source the UI library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/ui.sh"

msg_header "Neovim Installation"

msg_step "Detecting system information"

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
        msg_error "Unsupported architecture: $ARCH"
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
        msg_error "Unsupported OS: $OS"
        exit 1
        ;;
esac

msg_info "Detected OS: $OS, Architecture: $ARCH"
msg_info "Looking for: $FILENAME"
msg_success "System detection complete"

msg_step "Fetching latest Neovim release information"

# Get the latest release info from GitHub API
LATEST_RELEASE=$(curl -s https://api.github.com/repos/neovim/neovim/releases/latest)

# Extract the download URL for the detected platform
DOWNLOAD_URL=$(echo "$LATEST_RELEASE" | jq -r --arg filename "$FILENAME" '.assets[] | select(.name == $filename) | .browser_download_url')

# Extract version for logging
VERSION=$(echo "$LATEST_RELEASE" | jq -r '.tag_name')

# Check if we got a valid download URL
if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "null" ]; then
    msg_error "Could not find download URL for $FILENAME"
    msg_info "Available assets:"
    echo "$LATEST_RELEASE" | jq -r '.assets[].name'
    exit 1
fi

msg_info "Version: $VERSION"
msg_info "Download URL: $DOWNLOAD_URL"
msg_success "Release information retrieved"

msg_step "Downloading Neovim $VERSION"

# Create temporary directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Download the tar.gz file
if curl -L -o "$FILENAME" "$DOWNLOAD_URL" 2>&1 | grep -q "100"; then
    msg_success "Download complete"
else
    msg_success "Download complete"
fi

# Check if download was successful
if [ ! -f "$FILENAME" ]; then
    msg_error "Download failed"
    exit 1
fi

msg_step "Extracting archive"

# Extract the archive
tar -xzf "$FILENAME"
msg_success "Archive extracted"

msg_step "Installing to ~/.local"

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

msg_success "Files copied to ~/.local"

msg_step "Cleaning up temporary files"

# Clean up
cd /
rm -rf "$TEMP_DIR"

msg_success "Cleanup complete"

msg_footer "Neovim $VERSION installed successfully!"
msg_info "Make sure ~/.local/bin is in your PATH"
