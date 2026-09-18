#!/usr/bin/env bash
set -eu

# A rustup toolchain, and the one CLI tool conda-forge does not package.
#
# This used to install starship, eza and tree-sitter-cli as well. All three are
# conda-forge packages and are in bundles now, which created a conflict rather
# than a duplicate: ~/.zshrc sources ~/.cargo/env after it prepends
# ~/.pixi/bin, so ~/.cargo/bin lands in front and the cargo copy wins. The
# manifest would have said one thing and `command -v` another. So the tools that
# moved are uninstalled here, and only once their replacement is in place.
#
# Runs only where the machine entry sets rust = true.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UI_LIB="$SCRIPT_DIR/../lib/ui.sh"

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

PIXI_BIN_DIR="${PIXI_HOME:-$HOME/.pixi}/bin"

# Tools that moved to a pixi bundle. Each is uninstalled only when the pixi
# copy already exists, so a machine is never left without the command because a
# download failed.
#
# Mapping: binary_name:cargo_package_name
obsolete_tools="starship:starship eza:eza tree-sitter:tree-sitter-cli taplo:taplo-cli"

for item in $obsolete_tools; do
    bin_name="${item%%:*}"
    pkg_name="${item#*:}"
    if [ ! -e "$HOME/.cargo/bin/$bin_name" ]; then
        continue
    fi
    if [ ! -x "$PIXI_BIN_DIR/$bin_name" ]; then
        warning "$bin_name is installed by cargo and shadows the pixi copy, which is missing"
        hint "run 'chezmoi apply' again once 'pixi global sync' has succeeded"
        continue
    fi
    step "removing cargo's $bin_name; it comes from a pixi bundle now"
    if "$CARGO_BIN" uninstall "$pkg_name" >/dev/null 2>&1; then
        success "uninstalled $pkg_name"
    else
        # cargo refuses when the crate was installed under another name, so
        # report rather than delete the file behind cargo's back.
        warning "could not 'cargo uninstall $pkg_name'; remove $HOME/.cargo/bin/$bin_name by hand"
    fi
done

# What conda-forge does not have. tre-command is the only reason a toolchain is
# still installed on a machine that writes no Rust.
#
# Mapping: binary_name:package_name
ensure_tools="tre:tre-command"

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
