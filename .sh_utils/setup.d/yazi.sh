#!/bin/bash

# Script to install yazi file manager
# Uses the shared UI library for consistent output

set -e # Exit immediately if a command exits with a non-zero status

# Determine script directory and source UI library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UI_LIB="$SCRIPT_DIR/../lib/ui.sh"

# Source the UI library
if [ -f "$UI_LIB" ]; then
    source "$UI_LIB"
else
    echo "ERROR: UI library not found at $UI_LIB"
    exit 1
fi

msg_header "YAZI INSTALLATION"

# Get glibc version
msg_step "Checking glibc version"
glibc_version=$(getconf GNU_LIBC_VERSION | cut -d' ' -f2)
glibc_num=$(echo "$glibc_version" | awk -F. '{print $1 * 100 + $2}')
msg_success "glibc version: $glibc_version"

# Set installation directory
XDG_PREFIX_HOME="$HOME/.local"
mkdir -p "$XDG_PREFIX_HOME/bin"

if ((glibc_num >= 232)); then
    msg_step "Installing the latest yazi (linux, x86_64, gnu)"

    # Get download URL for latest release
    msg_info "Fetching latest release information..."
    download_url=$(curl -s "https://api.github.com/repos/sxyazi/yazi/releases/latest" | \
        grep -oP '(?<="browser_download_url": ")[^"]*yazi-x86_64-unknown-linux-gnu\.zip')

    if [ -z "$download_url" ]; then
        msg_error "Failed to get download URL"
        exit 1
    fi

    # Download yazi
    msg_info "Downloading yazi..."
    curl -sS -L --fail --retry 3 --retry-delay 1 -o yazi-x86_64-unknown-linux-gnu.zip "$download_url" &
    pid=$!
    spinner $pid
    if ! wait $pid; then
        msg_error "Download failed. Please ensure curl can access GitHub and try again."
        exit 1
    fi

    # Extract archive
    msg_info "Extracting archive..."
    unzip -qq yazi-x86_64-unknown-linux-gnu.zip &
    pid=$!
    spinner $pid
    if ! wait $pid; then
        msg_error "Failed to extract archive. Ensure unzip is installed."
        exit 1
    fi

    # Copy binaries
    msg_info "Installing binaries to $XDG_PREFIX_HOME/bin/"
    cp yazi-x86_64-unknown-linux-gnu/ya* "$XDG_PREFIX_HOME/bin/"

    # Cleanup
    msg_info "Cleaning up temporary files..."
    rm -r yazi-x86_64-unknown-linux-gnu*

    msg_success "yazi installed from pre-built binary"
else
    msg_warning "glibc version < 2.32, building from source (this may take several minutes)"

    # Get latest version tag
    msg_step "Fetching latest yazi version"
    YAZI_VERSION=$(curl -s "https://api.github.com/repos/sxyazi/yazi/releases/latest" | \
        grep -Po '"tag_name": "v\K[^"]*')

    if [ -z "$YAZI_VERSION" ]; then
        msg_error "Failed to get yazi version"
        exit 1
    fi
    msg_success "Latest version: v$YAZI_VERSION"

    # Check if cargo is installed
    if ! command -v cargo &> /dev/null; then
        msg_error "cargo (Rust) is not installed. Please install Rust first:"
        msg_info "Visit https://rustup.rs/ or run: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
        exit 1
    fi

    # Clone repository
    msg_step "Cloning yazi repository"
    git clone https://github.com/sxyazi/yazi >/dev/null 2>&1 &
    pid=$!
    spinner $pid
    wait $pid
    msg_success "Repository cloned"

    cd yazi

    # Checkout specific version
    msg_step "Checking out version v$YAZI_VERSION"
    git checkout "$YAZI_VERSION" >/dev/null 2>&1
    msg_success "Checked out v$YAZI_VERSION"

    # Build yazi
    msg_step "Building yazi (this may take several minutes)"
    msg_info "Running: cargo build --release --locked"
    cargo build --release --locked >/dev/null 2>&1 &
    pid=$!
    spinner $pid
    wait $pid
    msg_success "Build completed"

    # Install binaries
    msg_step "Installing binaries to $XDG_PREFIX_HOME/bin/"
    mv target/release/yazi target/release/ya "$XDG_PREFIX_HOME/bin/"
    msg_success "Binaries installed"

    # Cleanup
    cd ..
    msg_info "Cleaning up build directory..."
    rm -rf yazi

    msg_success "yazi built and installed from source"
fi

# Verify installation
msg_step "Verifying installation"
if [ -x "$XDG_PREFIX_HOME/bin/yazi" ]; then
    yazi_version=$("$XDG_PREFIX_HOME/bin/yazi" --version | cut -d' ' -f2)
    msg_success "yazi version: $yazi_version"
    msg_footer "YAZI INSTALLATION COMPLETE!"
else
    msg_error "Failed to install yazi - binary not found or not executable"
    exit 1
fi
