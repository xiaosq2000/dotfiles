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
    # Silence stderr locally and restore it afterwards (safe when sourced)
    exec {__saved_stderr}>&2 2>/dev/null
    echo "${BLUE}Software Overview: ${RESET}"
    local WIDTH=16
    software_overview_helper() {
        local format="${INDENT}%-${WIDTH}s%s\n"
        local not_found_format="${INDENT}${BOLD}${RED}%-${WIDTH}s%s${RESET}\n"
        local cli_name
        local version
        if [[ $# -eq 3 ]]; then
            format=$1
            cli_name=$2
            version=$3
        elif [[ $# -eq 2 ]]; then
            cli_name=$1
            version=$2
        else
            error "Given $# arguments, it should be 2 or 3."
            return 1
        fi
        local unaliased_name
        local print_only_not_found="false"
        # Resolve aliases portably across bash and zsh
        case "$(type -t "$cli_name" 2>/dev/null)" in
            alias)
                # Extract the first word of the alias expansion as the command
                unaliased_name=$(alias "$cli_name" 2>/dev/null | sed -E "s/^alias $cli_name='(.*)'$/\1/" | awk '{print $1}')
                ;;
            *)
                unaliased_name="$cli_name"
                ;;
        esac
        if has "$unaliased_name"; then
            if [[ ! $print_only_not_found == "true" ]]; then
                printf "$format" "$unaliased_name" "$version"
            fi
        else
            printf "$not_found_format" "$unaliased_name" "not found"
        fi
    }
    printf "${INDENT}%-${WIDTH}s${RESET}%s\n" "Linux Kernel" "$(uname -sr)"
    printf "${INDENT}%-${WIDTH}s${RESET}%s\n" "Linux Distro" "$(cat /etc/os-release | grep ^'PRETTY_NAME' | grep -oP '"\K[^"]+(?=")')"
    software_overview_helper "ldd" "$(ldd --version | head -n 1 | cut -f 1 -d ' ' --complement)"
    software_overview_helper "gcc" "$(gcc --version | head -n 1 | awk '{ print $4; }')"
    software_overview_helper "nvcc" "$(nvcc --version | sed -n '4p' | awk '{ print $5; }' | sed 's/.\$//')"
    if [ -f /.dockerenv ]; then
        warning "This is a docker container."
    fi
    if [[ ! -f /.dockerenv ]]; then
        software_overview_helper "docker" "$(docker --version | awk '{print $3}' | cut -d, -f1)"
    fi
    software_overview_helper "zsh" "$(zsh --version | awk '{ print $2; }')"
    software_overview_helper "tmux" "$(tmux -V | awk '{ print $2; }')"
    software_overview_helper "nvim" "$(nvim --version | head -n 1 | awk '{ print $2; }' | cut -dv -f2)"
    software_overview_helper "vim" "$(vim --version | head -n 1 | awk '{ print $5;}')"
    software_overview_helper "git" "$(git --version | awk '{ print $3; }')"
    software_overview_helper "git-lfs" "$(git-lfs --version | awk '{ print $1; }' | cut -d '/' -f 2)"
    software_overview_helper "lazygit" "$(lazygit --version | cut -d ',' -f 4 | cut -d '=' -f 2)"
    software_overview_helper "fzf" "$(fzf --version | cut -d ' ' -f 1)"
    software_overview_helper "cmake" "$(cmake --version | head -n 1 | awk '{ print $3; }')"
    software_overview_helper "ninja" "$(ninja --version)"
    software_overview_helper "cargo" "$(cargo --version | awk '{ print $2; }')"
    software_overview_helper "python" "$(python --version | awk '{ print $2; }')"
    software_overview_helper "conda" "$(conda --version | awk '{ print $2; }')"
    software_overview_helper "mamba" "$(mamba --version)"
    software_overview_helper "micromamba" "$(micromamba --version)"
    software_overview_helper "lua" "$(lua -v 2>&1 | cut -d ' ' -f 2)"
    software_overview_helper "luarocks" "$(luarocks --version | head -n 1 | cut -d ' ' -f 2)"
    software_overview_helper "gnome-shell" "$(gnome-shell --version | awk '{ print $3; }')"
    software_overview_helper "gnome-terminal" "$(gnome-terminal --version | awk '{ print $4; }')"
    software_overview_helper "alacritty" "$(alacritty --version | awk '{ print $2; }')"
    software_overview_helper "kitty" "$(kitty --version | awk '{ print $2; }')"
    software_overview_helper "xclip" "$(xclip -version 2>&1 | head -n 1 | awk '{ print $3;}')"
    software_overview_helper "zathura" "$(zathura --version | head -n 1 | awk '{ print $2; }')"
    software_overview_helper "TeX" "$(tex --version | grep -o '(.*)' | sed 's/[()]//g')"
    if [ -z "${ROS_DISTRO}" ]; then
        software_overview_helper "${INDENT}${RED}%-${WIDTH}s${RESET}%s\n" "ROS" "not found"
    else
        software_overview_helper "${INDENT}${GREEN}%-${WIDTH}s${RESET}%s\n" "ROS" "${ROS_DISTRO}"
    fi
    echo
    # Clean up helper regardless of shell
    if [ "$(type -t software_overview_helper 2>/dev/null)" = "function" ]; then
        unset -f software_overview_helper 2>/dev/null || unfunction software_overview_helper 2>/dev/null || true
    fi
    # Restore stderr
    exec 2>&${__saved_stderr}
    exec {__saved_stderr}>&-
}
