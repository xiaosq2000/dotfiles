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

# Ensure cargo is installed (without modifying PATH)
if [ -f "$HOME/.cargo/env" ]; then
    \. "$HOME/.cargo/env"
    CARGO_BIN="$(command -v cargo)"
else
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile default --no-modify-path
    if [ -f "$HOME/.cargo/env" ]; then
        \. "$HOME/.cargo/env"
        CARGO_BIN="$(command -v cargo)"
    else
        error "cargo installation failed"
        exit 1
    fi
fi

# If tools are missing from PATH, install them globally via cargo.
# Mapping: binary_name:package_name
ensure_tools="starship:starship tre:tre-command eza:eza tree-sitter:tree-sitter-cli"

missing_packages=""
for item in $ensure_tools; do
    bin_name="${item%%:*}"
    pkg_name="${item#*:}"
    if ! command -v "$bin_name" >/dev/null 2>&1; then
        info "missing '$bin_name'; will install package '$pkg_name'"
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
    set -- $pkgs
    # --locked: use each crate's shipped Cargo.lock. Without it cargo re-resolves
    # transitive deps to their newest semver-compatible versions, which breaks on
    # crates whose upstream published a semver-incompatible patch release
    # (e.g. eza pins palette =0.7.5, but palette_derive 0.7.7 resolves in and
    # emits code for palette >=0.7.6 internals).
    "$CARGO_BIN" install --locked "$@"
fi
