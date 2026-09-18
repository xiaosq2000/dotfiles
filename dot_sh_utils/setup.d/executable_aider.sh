#!/usr/bin/env sh
set -eu

# Install Aider using uv. Ensures uv is available.
# With httpcore[socks] to solve https://github.com/Aider-AI/aider/issues/3406

# Ensure ~/.local/bin on PATH for current shell
export PATH="$HOME/.local/bin:$PATH"

# Ensure uv is installed
if ! command -v uv >/dev/null 2>&1; then
    echo "[aider.sh] 'uv' not found. Attempting to install uv..."
    if [ -f "$HOME/.sh_utils/setup.d/uv.sh" ]; then
        chmod +x "$HOME/.sh_utils/setup.d/uv.sh"
        sh "$HOME/.sh_utils/setup.d/uv.sh"
    else
        # Fallback to official installer without modifying shell profiles
        curl -LsSf https://astral.sh/uv/install.sh | UV_NO_MODIFY_PATH=1 sh
    fi

    # Ensure the newly installed uv is on PATH for this session
    export PATH="$HOME/.local/bin:$PATH"

    if ! command -v uv >/dev/null 2>&1; then
        echo "[aider.sh] Failed to install 'uv'. Please install uv and re-run."
        exit 1
    fi
fi

# Install Aider as a uv tool
uv tool install --force --python python3.12 --with pip --with httpcore[socks] aider-chat@latest
