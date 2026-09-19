#!/usr/bin/env bash
set -eu

# Two jobs, and they are gated differently on purpose.
#
# Clearing out cargo copies of tools that moved into a pixi bundle happens
# wherever a cargo exists, because it is a correctness problem rather than a
# preference: the manifest says one thing and `command -v` another. imrl and
# sicc were in that state after the bundles landed, with cargo's eza and
# tree-sitter shadowing pixi's.
#
# The rc files no longer source ~/.cargo/env, which prepended ~/.cargo/bin and
# so put it in front of ~/.pixi/bin. They append ~/.cargo/bin instead, so pixi
# wins by construction and this script only has to remove the duplicates.
#
# Installing a toolchain happens only where the machine asks for it, which
# $RUST_TOOLCHAIN carries in from the machine entry's rust flag. A machine that
# does not want rust and has no cargo does nothing here at all.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UI_LIB="$SCRIPT_DIR/../lib/ui.sh"

if [ -f "$UI_LIB" ]; then
    # shellcheck disable=SC1090
    source "$UI_LIB"
else
    echo "error: UI library not found at $UI_LIB"
    exit 1
fi

# Whether this machine wants a toolchain. Set by the run script from the machine
# entry; default false so that running this by hand on a machine with no cargo
# does not quietly install one.
RUST_TOOLCHAIN="${RUST_TOOLCHAIN:-false}"

CARGO_BIN=""
if [ -f "$HOME/.cargo/env" ]; then
    # shellcheck disable=SC1091
    \. "$HOME/.cargo/env"
    CARGO_BIN="$(command -v cargo || true)"
elif [ "$RUST_TOOLCHAIN" = true ]; then
    step "installing a rustup toolchain"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile default --no-modify-path
    if [ -f "$HOME/.cargo/env" ]; then
        # shellcheck disable=SC1091
        \. "$HOME/.cargo/env"
        CARGO_BIN="$(command -v cargo || true)"
    fi
    if [ -z "$CARGO_BIN" ]; then
        error "cargo installation failed"
        exit 1
    fi
else
    info "no cargo here and this machine does not ask for one; nothing to do"
    exit 0
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

if [ "$RUST_TOOLCHAIN" != true ]; then
    info "cargo is present but this machine does not ask for a toolchain; leaving it alone"
    exit 0
fi

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
