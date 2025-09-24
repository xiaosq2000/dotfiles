#!/bin/bash

set -euo pipefail

echo "Installing latest Neovim..."

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
        echo "Error: Unsupported architecture: $ARCH"
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
        echo "Error: Unsupported OS: $OS"
        exit 1
        ;;
esac

echo "Detected OS: $OS, Architecture: $ARCH"
echo "Looking for: $FILENAME"

# Get the latest release info from GitHub API
LATEST_RELEASE=$(curl -s https://api.github.com/repos/neovim/neovim/releases/latest)

# Extract the download URL for the detected platform
DOWNLOAD_URL=$(echo "$LATEST_RELEASE" | jq -r --arg filename "$FILENAME" '.assets[] | select(.name == $filename) | .browser_download_url')

# Extract version for logging
VERSION=$(echo "$LATEST_RELEASE" | grep '"tag_name":' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')

echo "Downloading Neovim $VERSION..."

# Check if we got a valid download URL
if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "null" ]; then
    echo "Error: Could not find download URL for $FILENAME"
    echo "Available assets:"
    echo "$LATEST_RELEASE" | jq -r '.assets[].name'
    exit 1
fi

echo "Download URL: $DOWNLOAD_URL"

# Create temporary directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Download the tar.gz file
curl -L -o "$FILENAME" "$DOWNLOAD_URL"

# Check if download was successful
if [ ! -f "$FILENAME" ]; then
    echo "Error: Download failed"
    exit 1
fi

# Extract the archive
tar -xzf "$FILENAME"

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

# Clean up
cd /
rm -rf "$TEMP_DIR"

echo "Neovim $VERSION installed successfully to ~/.local"
echo "Make sure ~/.local/bin is in your PATH"
