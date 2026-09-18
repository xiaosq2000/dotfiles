#!/usr/bin/env bash
set -eu

# Configure pnpm's global install location. That is all this does now.
#
# It used to be 123 lines: map `uname -m` to a pnpm release asset, download the
# standalone binary into $PNPM_HOME/bin, then `pnpm env use --global lts` to
# fetch a Node runtime. Both pnpm and nodejs are conda-forge packages, so they
# are bundle entries in .chezmoidata/tools.toml and arrive with everything else.
#
# What is left cannot come from a package, because it is configuration of the
# user's pnpm store rather than software: without it, `pnpm add --global` either
# refuses to run for want of a global-bin-dir or installs into an isolated
# layout that the CLIs it installs cannot cope with.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UI_LIB="$SCRIPT_DIR/../lib/ui.sh"
if [ -f "$UI_LIB" ]; then
    # shellcheck disable=SC1090
    source "$UI_LIB"
else
    echo "error: UI library not found at $UI_LIB"
    exit 1
fi

header "pnpm global store"

# Keep this layout in sync with the pnpm block in ~/.zshrc.
export PNPM_HOME="${PNPM_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/pnpm}"
PNPM_BIN_DIR="$PNPM_HOME/bin"

if ! command -v pnpm >/dev/null 2>&1; then
    warning "pnpm not found on PATH"
    hint "it comes from the dev-web bundle; check .chezmoidata/machines.toml"
    exit 0
fi
PNPM="$(command -v pnpm)"

if ! command -v node >/dev/null 2>&1; then
    warning "node not found on PATH; pnpm's global CLIs will not run"
    hint "it comes from the dev-web bundle; check .chezmoidata/machines.toml"
fi

mkdir -p "$PNPM_BIN_DIR"

# Pin the global bin dir so globally-installed tools land in $PNPM_HOME/bin,
# matching the PATH entry in ~/.zshrc. pnpm otherwise picks a directory of its
# own choosing and warns that it is not on PATH.
"$PNPM" config set global-bin-dir "$PNPM_BIN_DIR" >/dev/null 2>&1 ||
    warning "could not set pnpm's global-bin-dir"

# Use a flat, npm-like global node_modules. pnpm's default isolated store hides
# transitive dependencies, which breaks CLIs that assume hoisting. This has to
# live in pnpm's global directory, which is keyed by store version.
PNPM_GLOBAL_DIR="$("$PNPM" root --global 2>/dev/null || true)"
if [ -n "$PNPM_GLOBAL_DIR" ]; then
    mkdir -p "$PNPM_GLOBAL_DIR"
    printf 'nodeLinker: hoisted\n' >"$PNPM_GLOBAL_DIR/pnpm-workspace.yaml"
    success "global store at $PNPM_GLOBAL_DIR (hoisted), binaries in $PNPM_BIN_DIR"
else
    warning "could not determine pnpm's global directory"
fi
