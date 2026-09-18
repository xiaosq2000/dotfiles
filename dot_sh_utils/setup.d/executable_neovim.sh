#!/usr/bin/env bash
set -euo pipefail

# Load UI library for consistent CLI output
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UI_LIB="${UI_LIB:-$SCRIPT_DIR/../lib/ui.sh}"
if [ -f "$UI_LIB" ]; then
    # shellcheck source=../lib/ui.sh
    source "$UI_LIB"
else
    echo "error: $UI_LIB not found"
    exit 1
fi

# Load platform detection utilities
PLATFORM_LIB="${PLATFORM_LIB:-$SCRIPT_DIR/../lib/platform.sh}"
if [ -f "$PLATFORM_LIB" ]; then
    # shellcheck source=../lib/platform.sh
    source "$PLATFORM_LIB"
else
    error "$PLATFORM_LIB not found"
    exit 1
fi

PREFIX="${XDG_PREFIX_HOME:-$HOME/.local}"
BIN_DIR="$PREFIX/bin"
REQUESTED_VERSION="${NVIM_VERSION:-}"

cleanup() {
    debug "cleaning up temporary files"
    if [ -n "${TEMP_DIR:-}" ] && [ -d "${TEMP_DIR:-}" ]; then
        rm -rf "$TEMP_DIR"
    fi
    debug "cleanup complete"
}

ensure_deps() {
    local missing=()
    for cmd in curl tar uname mktemp cp tr cut; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing required commands: ${missing[*]}"
        exit 1
    fi
}

usage() {
    printf '%s\n' "Usage: $(basename "$0") [--version VERSION]"
    printf '%s\n' ""
    printf '%s\n' "Options:"
    printf '%s\n' "      --version VERSION  Install a specific Neovim release (for example: 0.11.0 or v0.11.0)"
    printf '%s\n' "  -h, --help             Show this help"
    printf '%s\n' ""
    printf '%s\n' "Environment:"
    printf '%s\n' "  NVIM_VERSION           Default version override when --version is not provided"
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --version)
                if [ $# -lt 2 ]; then
                    error "missing value for --version"
                    usage
                    exit 1
                fi
                REQUESTED_VERSION="$2"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                error "unknown argument: $1"
                usage
                exit 1
                ;;
        esac
        shift
    done
}

normalize_version() {
    local version
    version="$1"

    case "$version" in
        ""|latest)
            printf '%s\n' ""
            ;;
        v*)
            printf '%s\n' "$version"
            ;;
        *)
            printf 'v%s\n' "$version"
            ;;
    esac
}

# Compute the exact asset filename based on known neovim naming convention.
# linux/darwin x amd64/arm64 → nvim-{linux|macos}-{x86_64|arm64}.tar.gz
nvim_asset_name() {
    local os arch os_token arch_token
    os="$(plat_os)"
    arch="$(plat_arch)"

    case "$os" in
        linux)  os_token="linux" ;;
        darwin) os_token="macos" ;;
        *) echo ""; return 1 ;;
    esac

    case "$arch" in
        amd64) arch_token="x86_64" ;;
        arm64) arch_token="arm64"  ;;
        *) echo ""; return 1 ;;
    esac

    echo "nvim-${os_token}-${arch_token}.tar.gz"
}

resolve_release() {
    local base latest_url requested_version
    OS="$(plat_os)"
    ARCH="$(plat_arch)"

    if [ "$OS" = "unknown" ] || [ "$ARCH" = "unknown" ]; then
        error "unsupported platform: $(plat_id)"
        exit 1
    fi

    FILENAME="$(nvim_asset_name)"
    if [ -z "${FILENAME:-}" ]; then
        error "failed to compute asset filename for $(plat_id)"
        exit 1
    fi

    debug "detected OS: $OS, architecture: $ARCH, looking for: $FILENAME"

    base="https://github.com/neovim/neovim/releases/latest"
    requested_version="$(normalize_version "$REQUESTED_VERSION")"

    if [ -n "$requested_version" ]; then
        VERSION="$requested_version"
        DOWNLOAD_URL="https://github.com/neovim/neovim/releases/download/$VERSION/$FILENAME"
        if ! curl -fsI "$DOWNLOAD_URL" >/dev/null; then
            error "neovim $VERSION asset not found for $(plat_id): $FILENAME"
            exit 1
        fi
    else
        DOWNLOAD_URL="$base/download/$FILENAME"
        if ! curl -fsI "$DOWNLOAD_URL" >/dev/null; then
            error "latest neovim asset not found for $(plat_id): $FILENAME"
            exit 1
        fi

        latest_url="$(curl -fsSL -o /dev/null -w "%{url_effective}" "$base")"
        VERSION="${latest_url##*/}"
    fi

    debug "version: $VERSION"
    debug "download URL: $DOWNLOAD_URL"
    debug "release information resolved"
}

install_neovim() {
    step "downloading neovim $VERSION"

    TEMP_DIR="$(mktemp -d)"
    trap cleanup EXIT

    local tarball stage
    tarball="$TEMP_DIR/$FILENAME"
    stage="$TEMP_DIR/stage"
    mkdir -p "$stage"

    curl -fsSLo "$tarball" "$DOWNLOAD_URL"
    debug "download complete"

    step "extracting archive"
    tar -xzf "$tarball" --strip-components=1 -C "$stage"
    debug "archive extracted"

    step "installing to $PREFIX"
    mkdir -p "$BIN_DIR"
    cp -a "$stage"/. "$PREFIX"/
    debug "files installed to $PREFIX"

    # Verify install
    if "$BIN_DIR/nvim" --version >/dev/null 2>&1; then
        local v
        v="$("$BIN_DIR/nvim" --version | head -n 1 | tr -s ' ' | cut -d ' ' -f 2)"
        success "nvim version: ${v}"
    else
        error "failed to install nvim"
        exit 1
    fi
}

main() {
    local normalized_version

    parse_args "$@"
    normalized_version="$(normalize_version "$REQUESTED_VERSION")"

    header "neovim - https://github.com/neovim/neovim"
    step "detecting system information"
    ensure_deps
    if [ -n "$normalized_version" ]; then
        step "resolving neovim $normalized_version release and asset URL"
    else
        step "resolving latest neovim release and asset URL"
    fi
    resolve_release
    install_neovim
    hint "make sure $BIN_DIR is in your PATH"
}

main "$@"
