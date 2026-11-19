# shellcheck shell=sh
# Shared POSIX environment for interactive, login, SSH, and agent shells.
# Sourced by ~/.zshenv, ~/.bashrc, ~/.profile, and BASH_ENV.
# Keep this file pure POSIX, side-effect-free, and completely silent.

export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

export PNPM_HOME="${PNPM_HOME:-$XDG_DATA_HOME/pnpm}"

# Prepend a directory only when absent so activated environments (pixi/venv)
# keep priority in nested shells.
_dotfiles_path_prepend_missing() {
    case ":$PATH:" in
        *":$1:"*) ;;
        *) PATH="$1${PATH:+:$PATH}" ;;
    esac
}

# Append a directory only when it exists and is absent.
_dotfiles_path_append_missing() {
    [ -d "$1" ] || return 0
    case ":$PATH:" in
        *":$1:"*) ;;
        *) PATH="${PATH:+$PATH:}$1" ;;
    esac
}

# Prepend lowest-to-highest priority so managed tools precede manual copies.
[ -d /usr/local/cuda/bin ] && _dotfiles_path_prepend_missing "/usr/local/cuda/bin"
_dotfiles_path_prepend_missing "$HOME/.local/bin"
[ -d "$PNPM_HOME/bin" ] && _dotfiles_path_prepend_missing "$PNPM_HOME/bin"
_dotfiles_path_prepend_missing "$HOME/.pixi/bin"
_dotfiles_path_prepend_missing "$HOME/.local/share/mise/shims"
_dotfiles_path_prepend_missing "$HOME/.local/opt/dotfiles/bin"
_dotfiles_path_append_missing "$HOME/.cargo/bin"
export PATH

unset -f _dotfiles_path_prepend_missing _dotfiles_path_append_missing

# Non-interactive bash shells (`bash -c` from agents, scripts, or editors) read
# BASH_ENV automatically when inherited.
export BASH_ENV="$XDG_CONFIG_HOME/dotfiles/env.sh"

# Coding-agent privacy and auto-update defaults.
export PI_TELEMETRY=0
export RTK_TELEMETRY_DISABLED=1
if [ -L "$HOME/.local/opt/dotfiles/bin/agy" ]; then
    export AGY_CLI_DISABLE_AUTO_UPDATE=true
fi
