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

# Load platform detection utilities
if ! declare -F plat_id >/dev/null 2>&1; then
    PLATFORM_LIB="${PLATFORM_LIB:-$HOME/.sh_utils/lib/platform.sh}"
    if [ -f "$PLATFORM_LIB" ]; then
        # shellcheck source=/dev/null
        source "$PLATFORM_LIB"
    else
        # Minimal fallback if platform.sh is unavailable
        plat_os() {
            case "$(uname -s)" in
                Linux) echo linux ;;
                Darwin) echo darwin ;;
                *) echo unknown ;;
            esac
        }
        plat_arch() {
            case "$(uname -m)" in
                x86_64|amd64) echo amd64 ;;
                arm64|aarch64) echo arm64 ;;
                *) echo unknown ;;
            esac
        }
        plat_id() {
            printf "%s-%s\n" "$(plat_os)" "$(plat_arch)"
        }
        plat_id_sep() {
            local sep="${1:-_}"
            printf "%s%s%s\n" "$(plat_os)" "$sep" "$(plat_arch)"
        }
        plat_arch_alias() {
            local style="${1:-}"
            case "$style:$(plat_arch)" in
                lazygit:amd64) echo x86_64 ;;
                lazygit:arm64) echo arm64 ;;
                *) echo ;;
            esac
        }
        plat_rust_triple() {
            case "$(plat_id)" in
                linux-amd64) echo x86_64-unknown-linux-gnu ;;
                linux-arm64) echo aarch64-unknown-linux-gnu ;;
                darwin-amd64) echo x86_64-apple-darwin ;;
                darwin-arm64) echo aarch64-apple-darwin ;;
                *) echo ;;
            esac
        }
    fi
fi

PREFIX="${XDG_PREFIX_HOME:-$HOME/.local}"
BIN_DIR="$PREFIX/bin"

ensure_deps() {
    local missing=()
    for cmd in curl tar install uname sed tr cut; do
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
    version="$(curl -fsSL "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | sed -nE 's/.*"tag_name":[[:space:]]*"v([^"]+)".*/\1/p' | head -n1)"
    if [ -z "${version:-}" ]; then
        msg_error "Unable to determine latest lazygit version"
        exit 1
    fi
    local os arch_token tarball
    os="$(plat_os)"
    arch_token="$(plat_arch_alias lazygit)"
    if [ -z "${arch_token:-}" ] || [ "$os" = "unknown" ]; then
        msg_error "Unsupported platform for lazygit: $(plat_id)"
        exit 1
    fi
    tarball="lazygit_${version}_${os}_${arch_token}.tar.gz"
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
    local triple asset
    triple="$(plat_rust_triple)"
    if [ -z "${triple:-}" ]; then
        msg_error "Unsupported platform for difftastic: $(plat_id)"
        exit 1
    fi
    asset="difft-${triple}.tar.gz"
    curl -fsSLo difft.tar.gz "https://github.com/Wilfred/difftastic/releases/latest/download/${asset}"
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
