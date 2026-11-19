#!/usr/bin/env bash

# Cross-shell compatibility shims (works for bash and zsh)
# Provide 'has' if not already defined
if ! command -v has >/dev/null 2>&1; then
    has() { command -v "$1" >/dev/null 2>&1; }
fi
# Provide 'unfunction' for bash (maps to unset -f)
if ! command -v unfunction >/dev/null 2>&1; then
    unfunction() { unset -f "$@" 2>/dev/null || true; }
fi
# Provide minimal UI fallbacks if ui.sh wasn't sourced
if ! command -v error >/dev/null 2>&1; then
    error() { printf 'error: %s\n' "$*" >&2; }
fi
if ! command -v warning >/dev/null 2>&1; then
    warning() { printf 'warning: %s\n' "$*"; }
fi
if ! command -v info >/dev/null 2>&1; then
    info() { printf '%s\n' "$*"; }
fi
if ! command -v debug >/dev/null 2>&1; then
    debug() { :; }
fi
# Safe default for INDENT if unset
: "${INDENT:=  }"
display_xdg_envs() {
    echo "${BLUE}XDG Environment Variables:${RESET}"
    echo "${INDENT}XDG_DATA_HOME=$XDG_DATA_HOME"
    echo "${INDENT}XDG_CONFIG_HOME=$XDG_CONFIG_HOME"
    echo "${INDENT}XDG_STATE_HOME=$XDG_STATE_HOME"
    echo "${INDENT}XDG_CACHE_HOME=$XDG_CACHE_HOME"
    echo "${INDENT}XDG_DATA_DIRS=$XDG_DATA_DIRS"
    echo "${INDENT}XDG_CONFIG_DIRS=$XDG_CONFIG_DIRS"
    echo "${INDENT}XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
    echo "${INDENT}# non-standard variables"
    echo "${INDENT}XDG_PREFIX_DIR=$XDG_PREFIX_DIR"
    echo "${INDENT}XDG_PREFIX_HOME=$XDG_PREFIX_HOME"
}

software_overview() {
    echo "${BLUE}Software Overview: ${RESET}"
    local WIDTH=16
    _software_overview_row() {
        local cli_name="$1"
        shift
        if has "$cli_name"; then
            local version
            version="$("$@" 2>/dev/null || true)"
            printf "${INDENT}%-${WIDTH}s%s\n" "$cli_name" "${version:-installed}"
        else
            printf "${INDENT}${BOLD}${RED}%-${WIDTH}s%s${RESET}\n" "$cli_name" "not found"
        fi
    }
    printf "${INDENT}%-${WIDTH}s${RESET}%s\n" "Linux Kernel" "$(uname -sr)"
    if [ -r /etc/os-release ]; then
        printf "${INDENT}%-${WIDTH}s${RESET}%s\n" "Linux Distro" "$(sed -n 's/^PRETTY_NAME="\([^"]*\)"/\1/p' /etc/os-release)"
    fi
    _software_overview_row "chezmoi" bash -c 'chezmoi --version | awk "{print \$3}" | tr -d ,'
    _software_overview_row "pixi" bash -c 'pixi --version | awk "{print \$2}"'
    _software_overview_row "mise" bash -c 'mise --version | awk "{print \$1}"'
    _software_overview_row "uv" bash -c 'uv --version | awk "{print \$2}"'
    _software_overview_row "zsh" bash -c 'zsh --version | awk "{print \$2}"'
    _software_overview_row "starship" bash -c 'starship --version | head -n1 | awk "{print \$2}"'
    _software_overview_row "sheldon" bash -c 'sheldon --version | awk "{print \$2}"'
    _software_overview_row "nvim" bash -c 'nvim --version | head -n1 | awk "{print \$2}" | sed "s/^v//"'
    _software_overview_row "tmux" bash -c 'tmux -V | awk "{print \$2}"'
    _software_overview_row "herdr" bash -c 'herdr --version | awk "{print \$2}"'
    _software_overview_row "git" bash -c 'git --version | awk "{print \$3}"'
    _software_overview_row "gh" bash -c 'gh --version | head -n1 | awk "{print \$3}"'
    _software_overview_row "difft" bash -c 'difft --version | awk "{print \$2}"'
    _software_overview_row "kitty" bash -c 'kitty --version | awk "{print \$2}"'
    _software_overview_row "yazi" bash -c 'yazi --version | awk "{print \$2}"'
    _software_overview_row "fzf" bash -c 'fzf --version | awk "{print \$1}"'
    _software_overview_row "zoxide" bash -c 'zoxide --version | awk "{print \$2}"'
    _software_overview_row "rg" bash -c 'rg --version | head -n1 | awk "{print \$2}"'
    _software_overview_row "fd" bash -c 'fd --version | awk "{print \$2}"'
    _software_overview_row "python3" bash -c 'python3 --version | awk "{print \$2}"'
    _software_overview_row "node" bash -c 'node --version | sed "s/^v//"'
    _software_overview_row "pnpm" pnpm --version
    _software_overview_row "pi" pi --version
    _software_overview_row "rtk" rtk --version
    _software_overview_row "agy" agy --version
    _software_overview_row "codex" codex --version
    _software_overview_row "claude" claude --version
    echo
    unset -f _software_overview_row 2>/dev/null || true
}
