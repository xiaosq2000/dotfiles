#!/usr/bin/env bash
set -eu

# Determine the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UI_LIB="$SCRIPT_DIR/../lib/ui.sh"

# Source the UI library
if [ -f "$UI_LIB" ]; then
    # shellcheck disable=SC1090
    source "$UI_LIB"
else
    echo "error: UI library not found at $UI_LIB"
    exit 1
fi

# Ensure uv is installed (without modifying PATH)
UV_BIN=""
if command -v uv >/dev/null 2>&1; then
    UV_BIN="$(command -v uv)"
else
    UV_INSTALL_DIR="${UV_INSTALL_DIR:-$HOME/.local/bin}"
    info "uv not found; installing to $UV_INSTALL_DIR"
    mkdir -p "$UV_INSTALL_DIR"
    if curl -LsSf https://astral.sh/uv/install.sh | UV_NO_MODIFY_PATH=1 UV_INSTALL_DIR="$UV_INSTALL_DIR" sh; then
        :
    else
        error "uv installation script failed"
        exit 1
    fi
    if [ -x "$UV_INSTALL_DIR/uv" ]; then
        UV_BIN="$UV_INSTALL_DIR/uv"
    elif command -v uv >/dev/null 2>&1; then
        UV_BIN="$(command -v uv)"
    else
        error "uv installation failed"
        exit 1
    fi
fi

info "uv is available at $UV_BIN"

# If tools are missing from PATH, install them globally via uv.
# Mapping: binary_name:package_name
ensure_tools="pre-commit:pre-commit nvitop:nvitop hf:huggingface_hub"

missing_packages=""
for item in $ensure_tools; do
    bin_name="${item%%:*}"
    pkg_name="${item#*:}"
    if ! command -v "$bin_name" >/dev/null 2>&1; then
        info "missing '$bin_name'; will install package '$pkg_name' via uv"
        case " $missing_packages " in
            *" $pkg_name "*) ;;
            *) missing_packages="$missing_packages $pkg_name" ;;
        esac
    else
        info "$bin_name is already installed at $(command -v "$bin_name")"
    fi
done

if [ -n "$missing_packages" ]; then
    pkgs="${missing_packages# }"
    # shellcheck disable=SC2086
    for pkg in $pkgs; do
        info "installing '$pkg' via uv"
        "$UV_BIN" tool install "$pkg"
    done
fi
