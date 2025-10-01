#!/usr/bin/env bash
set -euo pipefail

# Load UI library for consistent CLI output
if ! declare -F msg_step >/dev/null 2>&1; then
    UI_LIB="${UI_LIB:-$HOME/.sh_utils/lib/ui.sh}"
    if [ -f "$UI_LIB" ]; then
        # shellcheck source=/dev/null
        source "$UI_LIB"
    else
        # Fallback minimal UI if ui.sh is unavailable
        msg_step()    { echo "STEP: $*"; }
        msg_success() { echo "DONE: $*"; }
        msg_error()   { echo "ERROR: $*" >&2; }
        msg_warning() { echo "WARNING: $*"; }
        msg_info()    { echo "INFO: $*"; }
    fi
fi

PREFIX="${XDG_PREFIX_HOME:-$HOME/.local}"
BIN_DIR="$PREFIX/bin"

ensure_deps() {
    local missing=()
    for cmd in curl tar install; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        msg_error "Missing required commands: ${missing[*]}"
        exit 1
    fi
}

install_lazygit() {
    msg_step "Installing the latest lazygit"
    local version
    version="$(curl -fsSL "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')"
    if [ -z "${version:-}" ]; then
        msg_error "Unable to determine latest lazygit version"
        exit 1
    fi
    local tarball="lazygit_${version}_Linux_x86_64.tar.gz"
    curl -fsSLo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${version}/${tarball}"
    tar zxf lazygit.tar.gz lazygit
    install -Dm755 lazygit "$BIN_DIR/lazygit"
    rm -f lazygit.tar.gz lazygit
    if "$BIN_DIR/lazygit" --version >/dev/null 2>&1; then
        local v="$("$BIN_DIR/lazygit" --version | cut -d ',' -f 4 | cut -d '=' -f 2)"
        msg_success "lazygit version: ${v}"
    else
        msg_error "Failed to install lazygit"
        exit 1
    fi
}

install_difftastic() {
    msg_step "Installing the latest difftastic (difft)"
    curl -fsSLo difft.tar.gz "https://github.com/Wilfred/difftastic/releases/latest/download/difft-x86_64-unknown-linux-gnu.tar.gz"
    tar zxf difft.tar.gz
    install -Dm755 difft "$BIN_DIR/difft"
    rm -f difft.tar.gz difft
    if "$BIN_DIR/difft" --version >/dev/null 2>&1; then
        local v="$("$BIN_DIR/difft" --version | head -n 1 | cut -d ' ' -f 2)"
        msg_success "difft version: ${v}"
    else
        msg_error "Failed to install difft"
        exit 1
    fi
}

main() {
    msg_info "Installing Git tooling to $BIN_DIR"
    mkdir -p "$BIN_DIR"
    ensure_deps
    install_lazygit
    install_difftastic
}

main "$@"
