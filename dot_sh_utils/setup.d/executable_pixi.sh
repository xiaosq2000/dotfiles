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

# The global manifest lists the tools this machine should have. It is generated
# by chezmoi from the bundles the machine selects, so it is not hand-edited and
# not re-added:
#
#   .chezmoidata/tools.toml     which packages each bundle contains
#   .chezmoidata/machines.toml  which bundles each machine selects
#
# `pixi global install X` still works, and the next `chezmoi apply` still undoes
# it. To keep a tool, put its package in a bundle.
#
# Two consequences of sync worth knowing, both deliberate:
#   - it removes global environments that are absent from the manifest, which
#     is what keeps a machine from drifting and what makes deleting a bundle
#     actually reclaim the space;
#   - it has no "skip if already on PATH" escape hatch, so pixi installs its
#     own git even where /usr/bin/git exists. That is the point: the tool
#     versions then come from the manifest rather than from whatever the
#     host distribution happens to ship.
PIXI_HOME="${PIXI_HOME:-$HOME/.pixi}"
MANIFEST="$PIXI_HOME/manifests/pixi-global.toml"

if [ ! -f "$MANIFEST" ]; then
    error "pixi global manifest not found at $MANIFEST"
    error "chezmoi renders it from .chezmoidata/tools.toml; run 'chezmoi apply' first"
    exit 1
fi

# Refuse to prune the tool that invoked this script.
#
# chezmoi runs this from run_onchange_after_05-pixi.sh, and sync removes any
# environment missing from the manifest. Dropping chezmoi from the core bundle
# therefore makes `chezmoi apply` uninstall chezmoi, leaving no chezmoi to apply
# with. That happened once during the migration, back when the manifest was
# hand-held; this turns it into a message instead.
if [ -x "$PIXI_HOME/bin/chezmoi" ] && ! grep -q '^\[envs\.chezmoi\]' "$MANIFEST"; then
    error "chezmoi is installed via pixi but absent from $MANIFEST"
    error "syncing would uninstall it, leaving no chezmoi to apply with"
    error "fix by putting chezmoi back in the core bundle in .chezmoidata/tools.toml"
    exit 1
fi

info "syncing global tools from $MANIFEST"
"$PIXI_BIN" global sync
