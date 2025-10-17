#!/usr/bin/env bash
set -euo pipefail

# Typeface installer:
# - Installs Maple Mono (NF CN unhinted) into ${XDG_DATA_HOME:-$HOME/.local/share}/fonts/MapleMono-NF-CN-unhinted
# - Fetches the latest release from GitHub
# - Refreshes the font cache via fc-cache

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load UI library for consistent CLI output
UI_LIB="${UI_LIB:-$SCRIPT_DIR/../lib/ui.sh}"
if [ -f "$UI_LIB" ]; then
    # shellcheck source=lib/ui.sh
    source "$UI_LIB"
else
    echo "error: $UI_LIB not found"
    exit 1
fi

FONTS_BASE="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
MAPLE_DIR="$FONTS_BASE/MapleMono-NF-CN-unhinted"
ZIP_NAME="MapleMono-NF-CN-unhinted.zip"

ensure_deps() {
    local missing=()
    for cmd in curl unzip fc-cache sed mktemp; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing required commands: ${missing[*]}"
        exit 1
    fi
}

latest_maple_version() {
    curl -fsSL "https://api.github.com/repos/subframe7536/maple-font/releases/latest" \
        | sed -nE 's/.*"tag_name":[[:space:]]*"v([^"]+)".*/\1/p' \
        | head -n1
}

install_maple_mono_nf_cn_unhinted() {
    step "installing Maple Mono (NF CN unhinted)"
    mkdir -p "$MAPLE_DIR"

    local version
    version="$(latest_maple_version)"
    if [ -z "${version:-}" ]; then
        error "unable to determine latest Maple Mono release"
        exit 1
    fi
    info "latest Maple Mono version: ${version}"

    local version_file="$MAPLE_DIR/.installed-version"
    if [ -f "$version_file" ] && [ "$(cat "$version_file")" = "$version" ] && ls "$MAPLE_DIR"/*.ttf >/dev/null 2>&1; then
        success "Maple Mono (NF CN unhinted) is already at latest (${version})"
        return 0
    fi

    local tmpd
    tmpd="$(mktemp -d)"
    trap "rm -rf '$tmpd'" EXIT

    local url="https://github.com/subframe7536/maple-font/releases/download/v${version}/${ZIP_NAME}"

    step "downloading ${ZIP_NAME}"
    curl -fsSLo "$tmpd/${ZIP_NAME}" "$url"

    step "extracting fonts to ${MAPLE_DIR}"
    # Note: The ZIP contains TTF files at its root; -d ensures they end up in the target directory.
    unzip -o -q "$tmpd/${ZIP_NAME}" -d "$MAPLE_DIR"

    if ! ls "$MAPLE_DIR"/*.ttf >/dev/null 2>&1; then
        error "no .ttf files found after extraction"
        exit 1
    fi

    printf '%s\n' "$version" >"$version_file"

    step "refreshing font cache"
    fc-cache -f "$FONTS_BASE" >/dev/null 2>&1 || true

    success "installed Maple Mono (NF CN unhinted) v${version} in ${MAPLE_DIR}"
}

main() {
    header "typefaces installation"
    mkdir -p "$FONTS_BASE"
    ensure_deps
    install_maple_mono_nf_cn_unhinted
    footer "typefaces installation"
}

main "$@"
