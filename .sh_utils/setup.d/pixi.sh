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

# Ensure pixi is installed (without modifying PATH)
if command -v pixi >/dev/null 2>&1; then
    PIXI_BIN="$(command -v pixi)"
elif [ -x "$HOME/.pixi/bin/pixi" ]; then
    PIXI_BIN="$HOME/.pixi/bin/pixi"
else
    curl -fsSL https://pixi.sh/install.sh | PIXI_NO_PATH_UPDATE=1 sh
    if [ -x "$HOME/.pixi/bin/pixi" ]; then
        PIXI_BIN="$HOME/.pixi/bin/pixi"
    elif command -v pixi >/dev/null 2>&1; then
        PIXI_BIN="$(command -v pixi)"
    else
        error "pixi installation failed or is not on PATH"
        exit 1
    fi
fi

# If tools are missing from PATH, install them globally via pixi.
# Mapping: binary_name:package_name
ensure_tools="zsh:zsh git-lfs:git-lfs gh:gh btop:btop rg:ripgrep fastfetch:fastfetch fd:fd-find speedtest:speedtest-cli"

missing_packages=""
for item in $ensure_tools; do
    bin_name="${item%%:*}"
    pkg_name="${item#*:}"
    if ! command -v "$bin_name" >/dev/null 2>&1; then
        debug "Missing '$bin_name'; will install package '$pkg_name'"
        info "downloading $pkg_name"
        case " $missing_packages " in
            *" $pkg_name "*) ;;
            *) missing_packages="$missing_packages $pkg_name" ;;
        esac
    else
        debug "$bin_name is already installed at $(command -v "$bin_name")"
    fi
done

if [ -n "$missing_packages" ]; then
    pkgs="${missing_packages# }"
    # shellcheck disable=SC2086
    set -- $pkgs
    "$PIXI_BIN" global install "$@"
fi
