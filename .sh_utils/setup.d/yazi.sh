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

# Use a dedicated temp directory instead of CWD
TMP_DIR="$(mktemp -d -t yazi-install-XXXXXXXX)"
# Ensure cleanup on exit
cleanup() {
    [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ] && rm -rf "$TMP_DIR" || true
}
trap cleanup EXIT INT TERM

# Parse arguments
FORCE_SOURCE=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--force-source)
            FORCE_SOURCE=1
            shift
            ;;
        -h|--help)
            msg_info "Usage: $(basename "$0") [--force-source]"
            exit 0
            ;;
        *)
            msg_error "Unknown option: $1"
            msg_info "Usage: $(basename "$0") [--force-source]"
            exit 2
            ;;
    esac
done

# Get glibc version
msg_step "Checking glibc version"
glibc_version=$(getconf GNU_LIBC_VERSION | cut -d' ' -f2)
glibc_num=$(echo "$glibc_version" | awk -F. '{print $1 * 100 + $2}')

# Minimum glibc required for latest prebuilt yazi binary
REQUIRED_GLIBC="${REQUIRED_GLIBC:-2.39}"
required_glibc_num=$(echo "$REQUIRED_GLIBC" | awk -F. '{print $1 * 100 + $2}')

msg_success "glibc version: $glibc_version"

# Set installation directory
XDG_PREFIX_HOME="${XDG_PREFIX_HOME:-$HOME/.local}"
mkdir -p "$XDG_PREFIX_HOME/bin"

if ((glibc_num >= required_glibc_num)) && (( FORCE_SOURCE == 0 )); then
    msg_step "Installing the latest yazi (linux, x86_64, gnu)"

    # Get download URL for latest release (avoid grep -P for portability)
    msg_info "Fetching latest release information..."
    download_url=$(curl -s "https://api.github.com/repos/sxyazi/yazi/releases/latest" | \
        sed -n 's/.*"browser_download_url": "\(.*yazi-x86_64-unknown-linux-gnu.zip\)".*/\1/p' | head -n1)

    if [ -z "$download_url" ]; then
        msg_error "Failed to get download URL"
        exit 1
    fi

    # Download yazi to temp dir
    msg_info "Downloading yazi..."
    (
      cd "$TMP_DIR"
      curl -sS -L --fail --retry 3 --retry-delay 1 -o yazi-x86_64-unknown-linux-gnu.zip "$download_url"
    ) &
    pid=$!
    spinner $pid
    if ! wait $pid; then
        msg_error "Download failed. Please ensure curl can access GitHub and try again."
        exit 1
    fi

    # Extract archive
    msg_info "Extracting archive..."
    (
      cd "$TMP_DIR" && unzip -qq yazi-x86_64-unknown-linux-gnu.zip
    ) &
    pid=$!
    spinner $pid
    if ! wait $pid; then
        msg_error "Failed to extract archive. Ensure unzip is installed."
        exit 1
    fi

    # Copy binaries
    msg_info "Installing binaries to $XDG_PREFIX_HOME/bin/"
    if [ -d "$TMP_DIR/yazi-x86_64-unknown-linux-gnu" ]; then
        cp "$TMP_DIR"/yazi-x86_64-unknown-linux-gnu/ya* "$XDG_PREFIX_HOME/bin/" 2>/dev/null || true
        cp "$TMP_DIR"/yazi-x86_64-unknown-linux-gnu/yazi "$XDG_PREFIX_HOME/bin/" 2>/dev/null || true
    else
        msg_error "Extracted directory not found"
        exit 1
    fi

    # Cleanup of temp dir happens via trap

    msg_success "yazi installed from pre-built binary"
else
    if (( FORCE_SOURCE )); then
        msg_warning "Force source build requested; building from source (this may take several minutes)"
    else
        msg_warning "glibc version < $REQUIRED_GLIBC, building from source (this may take several minutes)"
    fi

    # Check if cargo is installed
    if ! command -v cargo &> /dev/null; then
        msg_error "cargo (Rust) is not installed. Please install Rust first:"
        msg_info "Visit https://rustup.rs/ or run: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
        exit 1
    fi

    # Clone repository
    msg_step "Cloning yazi repository"
    (
      cd "$TMP_DIR" && git clone --quiet https://github.com/sxyazi/yazi
    ) &
    pid=$!
    spinner $pid
    if ! wait $pid; then
        msg_error "Failed to clone repository"
        exit 1
    fi
    msg_success "Repository cloned"

    # Determine latest tag in the repo to avoid API parsing issues
    pushd "$TMP_DIR/yazi" >/dev/null
    msg_step "Detecting latest version tag"
    # Ensure tags are available (in case clone didn't fetch all tags)
    git fetch --tags --quiet || true
    LATEST_TAG=$(git describe --tags "$(git rev-list --tags --max-count=1)" 2>/dev/null || true)
    if [ -z "$LATEST_TAG" ]; then
        msg_warning "Could not determine latest tag; using default branch"
    else
        msg_info "Latest tag: $LATEST_TAG"
        if ! git checkout --quiet "$LATEST_TAG"; then
            msg_warning "Checkout of $LATEST_TAG failed; staying on default branch"
        else
            msg_success "Checked out $LATEST_TAG"
        fi
    fi

    # Build yazi
    msg_step "Building yazi (this may take several minutes)"
    msg_info "Running: cargo build --release --locked"
    cargo build --release --locked >/dev/null 2>&1 &
    pid=$!
    spinner $pid
    if ! wait $pid; then
        msg_error "Build failed. Check your Rust toolchain and dependencies."
        exit 1
    fi
    msg_success "Build completed"

    # Install binaries
    msg_step "Installing binaries to $XDG_PREFIX_HOME/bin/"
    installed_any=0
    if [ -f "target/release/yazi" ]; then
        cp "target/release/yazi" "$XDG_PREFIX_HOME/bin/" && installed_any=1
    fi
    if [ -f "target/release/ya" ]; then
        cp "target/release/ya" "$XDG_PREFIX_HOME/bin/" && installed_any=1
    fi
    if [ "$installed_any" -eq 0 ]; then
        msg_error "No expected binaries found in target/release"
        popd >/dev/null
        exit 1
    fi
    msg_success "Binaries installed"

    # Cleanup
    popd >/dev/null
    msg_info "Build directory will be cleaned up"

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
