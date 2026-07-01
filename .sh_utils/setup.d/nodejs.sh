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

# pnpm doubles as the Node.js version manager (replaces nvm + system node).
# Keep this layout in sync with the pnpm block in ~/.zshrc.
export PNPM_HOME="${PNPM_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/pnpm}"
PNPM_BIN_DIR="$PNPM_HOME/bin"
case ":$PATH:" in
    *":$PNPM_BIN_DIR:"*) ;;
    *) export PATH="$PNPM_BIN_DIR:$PATH" ;;
esac

# Map `uname -m` to the pnpm release asset suffix.
case "$(uname -m)" in
    x86_64 | amd64) PNPM_ARCH="x64" ;;
    aarch64 | arm64) PNPM_ARCH="arm64" ;;
    *)
        error "unsupported architecture: $(uname -m)"
        exit 1
        ;;
esac
# musl libc (e.g. Alpine) needs the statically-linked build.
PNPM_LIBC=""
if ldd --version 2>&1 | grep -qi musl; then
    PNPM_LIBC="-musl"
fi
PNPM_ASSET="pnpm-linux-${PNPM_ARCH}${PNPM_LIBC}.tar.gz"

# Ensure the standalone pnpm binary is installed. The linux release is a Node
# SEA binary that needs its sibling `dist/` tree, so extract the whole tarball
# into $PNPM_HOME/bin. Being self-contained, `pnpm env` can then manage node
# without a pre-existing node install.
if command -v pnpm >/dev/null 2>&1; then
    PNPM="$(command -v pnpm)"
    success "pnpm already installed: $("$PNPM" --version)"
else
    step "Installing the latest pnpm"
    mkdir -p "$PNPM_BIN_DIR"
    PNPM="$PNPM_BIN_DIR/pnpm"
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT
    if curl -fsSL "https://github.com/pnpm/pnpm/releases/latest/download/${PNPM_ASSET}" -o "$tmpdir/pnpm.tar.gz" &&
        tar xzf "$tmpdir/pnpm.tar.gz" -C "$PNPM_BIN_DIR"; then
        chmod +x "$PNPM"
        success "pnpm version: $("$PNPM" --version)"
    else
        error "Failed to install pnpm"
        rm -f "$PNPM"
        exit 1
    fi
    rm -rf "$tmpdir"
    trap - EXIT
fi

# Pin the global bin dir so globally-installed tools (node, bw, ...) land in
# $PNPM_HOME/bin, matching the PATH entry above and in ~/.zshrc.
"$PNPM" config set global-bin-dir "$PNPM_BIN_DIR" 1>/dev/null 2>&1 || true

# Use a flat, npm-like global node_modules. pnpm's default isolated store hides
# transitive deps, which breaks CLIs that assume hoisting (e.g. @bitwarden/cli
# needs `buffer/`). This must live in pnpm's global dir, keyed by store version.
PNPM_GLOBAL_DIR="$("$PNPM" root --global 2>/dev/null || true)"
if [ -n "$PNPM_GLOBAL_DIR" ]; then
    mkdir -p "$PNPM_GLOBAL_DIR"
    printf 'nodeLinker: hoisted\n' >"$PNPM_GLOBAL_DIR/pnpm-workspace.yaml"
fi

step "Installing the latest lts node.js"
if "$PNPM" env use --global lts 1>/dev/null 2>&1; then
    success "node version: $("$PNPM_BIN_DIR/node" --version)"
else
    error "Failed to install node"
    exit 1
fi

step "Installing bw"
if "$PNPM" add --global @bitwarden/cli 1>/dev/null 2>&1; then
    success "$("$PNPM_BIN_DIR/bw" --version)"
else
    error "Failed to install bw"
    exit 1
fi

# step "Installing deno"
# "$PNPM" add --global deno 1>/dev/null 2>&1
# if [ $? -eq 0 ]; then
#     success "$(deno --version | head -n 1)"
# else
#     error "Failed to install deno"
#     exit 1
# fi
#
# step "Installing claude code"
# "$PNPM" add --global @anthropic-ai/claude-code 1>/dev/null 2>&1
# if [ $? -eq 0 ]; then
#     success "$(claude --version)"
# else
#     error "Failed to install claude code"
#     exit 1
# fi
#
# step "Installing codex"
# "$PNPM" add --global @openai/codex 1>/dev/null 2>&1
# if [ $? -eq 0 ]; then
#     success "$(codex --version)"
# else
#     error "Failed to install codex"
#     exit 1
# fi
#
# step "Installing opencode"
# "$PNPM" add --global opencode-ai 1>/dev/null 2>&1
# if [ $? -eq 0 ]; then
#     success "$(opencode --version)"
# else
#     error "Failed to install opencode"
#     exit 1
# fi
