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

ensure_deps() {
    local missing=()
    for cmd in curl tar install uname sed tr cut head; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing required commands: ${missing[*]}"
        exit 1
    fi
}

install_lazydocker() {
    header "lazydocker - https://github.com/jesseduffield/lazydocker"
    step "installing the latest lazydocker"
    local version
    version="$(curl -fsSL "https://api.github.com/repos/jesseduffield/lazydocker/releases/latest" | sed -nE 's/.*"tag_name":[[:space:]]*"v([^"]+)".*/\1/p' | head -n1)"
    if [ -z "${version:-}" ]; then
        error "unable to determine latest lazydocker version"
        exit 1
    fi
    local os arch_token os_token tarball
    os="$(plat_os)"
    os_token="$(plat_os_title)"
    arch_token="$(plat_arch_alias lazydocker)"
    if [ -z "${arch_token:-}" ] || [ "$os" = "unknown" ] || [ -z "${os_token:-}" ]; then
        error "unsupported platform for lazydocker: $(plat_id)"
        exit 1
    fi
    tarball="lazydocker_${version}_${os_token}_${arch_token}.tar.gz"
    curl -fsSLo lazydocker.tar.gz "https://github.com/jesseduffield/lazydocker/releases/download/v${version}/${tarball}"
    tar zxf lazydocker.tar.gz lazydocker
    install -Dm755 lazydocker "$BIN_DIR/lazydocker"
    rm -f lazydocker.tar.gz lazydocker
    if "$BIN_DIR/lazydocker" --version >/dev/null 2>&1; then
        local v
        v="$("$BIN_DIR/lazydocker" --version | head -n 1 | cut -d' ' -f 2)"
        success "lazydocker version: ${v}"
    else
        error "failed to install lazydocker"
        exit 1
    fi
}

main() {
    mkdir -p "$BIN_DIR"
    ensure_deps
    install_lazydocker
}

main "$@"
