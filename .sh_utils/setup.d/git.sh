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
    for cmd in curl tar install uname sed tr cut; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing required commands: ${missing[*]}"
        exit 1
    fi
}

install_lazygit() {
    step "installing the latest lazygit"
    local version
    version="$(curl -fsSL "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | sed -nE 's/.*"tag_name":[[:space:]]*"v([^"]+)".*/\1/p' | head -n1)"
    if [ -z "${version:-}" ]; then
        error "unable to determine latest lazygit version"
        exit 1
    fi
    local os arch_token tarball
    os="$(plat_os)"
    arch_token="$(plat_arch_alias lazygit)"
    if [ -z "${arch_token:-}" ] || [ "$os" = "unknown" ]; then
        error "unsupported platform for lazygit: $(plat_id)"
        exit 1
    fi
    tarball="lazygit_${version}_${os}_${arch_token}.tar.gz"
    curl -fsSLo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${version}/${tarball}"
    tar zxf lazygit.tar.gz lazygit
    install -Dm755 lazygit "$BIN_DIR/lazygit"
    rm -f lazygit.tar.gz lazygit
    if "$BIN_DIR/lazygit" --version >/dev/null 2>&1; then
        local v
        v="$("$BIN_DIR/lazygit" --version | cut -d ',' -f 4 | cut -d '=' -f 2)"
        success "lazygit version: ${v}"
    else
        error "failed to install lazygit"
        exit 1
    fi
}

install_difftastic() {
    step "installing the latest difftastic (difft)"
    local triple asset
    triple="$(plat_rust_triple)"
    if [ -z "${triple:-}" ]; then
        error "unsupported platform for difftastic: $(plat_id)"
        exit 1
    fi
    asset="difft-${triple}.tar.gz"
    curl -fsSLo difft.tar.gz "https://github.com/Wilfred/difftastic/releases/latest/download/${asset}"
    tar zxf difft.tar.gz
    install -Dm755 difft "$BIN_DIR/difft"
    rm -f difft.tar.gz difft
    if "$BIN_DIR/difft" --version >/dev/null 2>&1; then
        local v
        v="$("$BIN_DIR/difft" --version | head -n 1 | cut -d ' ' -f 2)"
        success "difft version: ${v}"
    else
        error "failed to install difft"
        exit 1
    fi
}

main() {
    mkdir -p "$BIN_DIR"
    ensure_deps
    header "lazygit - https://github.com/jesseduffield/lazygit"
    install_lazygit
    footer "lazygit - https://github.com/jesseduffield/lazygit"
    header "difftastic - https://github.com/Wilfred/difftastic"
    install_difftastic
    footer "difftastic - https://github.com/Wilfred/difftastic"
}

main "$@"
