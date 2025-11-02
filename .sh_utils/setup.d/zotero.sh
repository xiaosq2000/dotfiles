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
INSTALL_DIR="${PREFIX}/zotero"
DESKTOP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
DOWNLOAD_BASE="https://www.zotero.org/download/client/dl?channel=release&platform=linux-x86_64"

SKIP_DESKTOP=0
FORCE=0

cleanup() {
    debug "cleaning up temporary files"
    if [ -n "${TEMP_DIR:-}" ] && [ -d "${TEMP_DIR:-}" ]; then
        rm -rf "$TEMP_DIR"
    fi
    debug "cleanup complete"
}

usage() {
    cat <<'EOF'
Usage: zotero.sh [options]

Options:
      --skip-desktop  Skip desktop entry/icon setup
  -f, --force         Reinstall even if Zotero is already installed
  -h, --help          Show this help
EOF
}

ensure_deps() {
    local missing=()
    for cmd in curl tar mktemp cp ln chmod; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing required commands: ${missing[*]}"
        exit 1
    fi
}


resolve_release() {
    step "preparing download URL"
    # Download directly from the canonical Zotero redirect URL; curl -L will follow redirects.
    LATEST_URL="$DOWNLOAD_BASE"
    debug "download URL: $LATEST_URL"
}

install_zotero() {
    step "downloading zotero"

    TEMP_DIR="$(mktemp -d)"
    trap cleanup EXIT

    local tarball stage
    tarball="$TEMP_DIR/zotero.tar.bz2"
    stage="$TEMP_DIR/stage"
    mkdir -p "$stage"

    curl -fsSLo "$tarball" "$LATEST_URL"
    debug "download complete"

    step "extracting archive"
    tar -jxf "$tarball" --strip-components=1 -C "$stage"
    debug "archive extracted"

    step "installing to $INSTALL_DIR"
    rm -rf "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    cp -a "$stage"/. "$INSTALL_DIR"/
    debug "files installed to $INSTALL_DIR"

    # Verify install
    if [ -x "$INSTALL_DIR/zotero" ]; then
        success "zotero installed"
    else
        error "failed to install zotero"
        exit 1
    fi
}

setup_desktop() {
    step "configuring desktop integration"

    if [ -x "${INSTALL_DIR}/set_launcher_icon" ]; then
        chmod +x "${INSTALL_DIR}/set_launcher_icon" || true
        set +e
        . "${INSTALL_DIR}/set_launcher_icon"
        local rc=$?
        set -e
        if [ $rc -ne 0 ]; then
            debug "set_launcher_icon exited with code $rc"
        fi
    else
        debug "set_launcher_icon not found; skipping icon setup"
    fi

    if [ -f "${INSTALL_DIR}/zotero.desktop" ]; then
        chmod +x "${INSTALL_DIR}/zotero.desktop" || true
        mkdir -p "$DESKTOP_DIR"
        ln -sf "${INSTALL_DIR}/zotero.desktop" "${DESKTOP_DIR}/zotero.desktop"
        debug "desktop entry linked to ${DESKTOP_DIR}/zotero.desktop"
        if command -v update-desktop-database >/dev/null 2>&1; then
            debug "updating desktop database"
            update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
        fi
        success "desktop entry installed"
    else
        debug "zotero.desktop not found; skipping desktop entry"
    fi
}

main() {
    # Parse args
    while [ $# -gt 0 ]; do
        case "$1" in
            --skip-desktop) SKIP_DESKTOP=1 ;;
            -f|--force) FORCE=1 ;;
            -h|--help) usage; exit 0 ;;
            *) error "unknown argument: $1"; usage; exit 1 ;;
        esac
        shift
    done

    header "zotero - https://www.zotero.org/"
    step "detecting system information"
    ensure_deps

    if [ "$(plat_id)" != "linux-amd64" ]; then
        error "unsupported platform: $(plat_id). only linux-amd64 is supported now."
        exit 1
    fi

    step "checking existing installation"
    if command -v zotero >/dev/null 2>&1; then
        if [ "$(command -v zotero)" != "$INSTALL_DIR/zotero" ]; then
            hint "Zotero found on PATH at: $(command -v zotero)"
            hint "this script manages the local install at: $INSTALL_DIR"
        fi
    fi

    # If Zotero is already installed (either managed here or available on PATH) and not forcing, skip reinstall
    if [ -x "$INSTALL_DIR/zotero" ] || command -v zotero >/dev/null 2>&1; then
        if [ "$FORCE" -eq 0 ]; then
            success "zotero is already available"
            if [ -x "$INSTALL_DIR/zotero" ] && [ "$SKIP_DESKTOP" -eq 0 ]; then
                setup_desktop
            fi
            step "symlinking \"$INSTALL_DIR/zotero\" to \"$PREFIX/bin/zotero\""
            ln -sf "$INSTALL_DIR/zotero" "$PREFIX/bin/zotero"
            hint "use --force to reinstall"
            exit 0
        else
            step "force reinstallation requested; continuing"
        fi
    fi

    resolve_release

    install_zotero

    if [ "$SKIP_DESKTOP" -eq 0 ]; then
        setup_desktop
    else
        debug "skipping desktop integration"
    fi

    step "symlinking \"$INSTALL_DIR/zotero\" to \"$PREFIX/bin/zotero\""
    ln -sf "$INSTALL_DIR/zotero" "$PREFIX/bin/zotero"

    hint "You can launch Zotero via the desktop entry or by running \`zotero\` in CLI"
}

main "$@"
