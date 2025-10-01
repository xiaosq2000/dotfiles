#!/usr/env/bin bash
DEBUG=false
INDENT='    '
BOLD="$(tput bold 2>/dev/null || printf '')"
GREY="$(tput setaf 0 2>/dev/null || printf '')"
UNDERLINE="$(tput smul 2>/dev/null || printf '')"
RED="$(tput setaf 1 2>/dev/null || printf '')"
GREEN="$(tput setaf 2 2>/dev/null || printf '')"
YELLOW="$(tput setaf 3 2>/dev/null || printf '')"
BLUE="$(tput setaf 4 2>/dev/null || printf '')"
MAGENTA="$(tput setaf 5 2>/dev/null || printf '')"
RESET="$(tput sgr0 2>/dev/null || printf '')"
error() {
    printf '%s\n' "${BOLD}${RED}ERROR:${RESET} $*" >&2
}
warning() {
    printf '%s\n' "${BOLD}${YELLOW}WARNING:${RESET} $*"
}
info() {
    printf '%s\n' "${BOLD}${GREEN}INFO:${RESET} $*"
}
debug() {
    [ "$DEBUG" = "true" ] && printf '%s\n' "${BOLD}${GREY}DEBUG:${RESET} $*"
}
completed() {
    printf '%s\n' "${BOLD}${GREEN}✓${RESET} $*"
}

has() {
  command -v "$1" 1>/dev/null 2>&1
}

safely_source() {
    if [[ -f "$1" ]]; then
        source "$1"
    else
        warning "$1 is not found."
    fi
}
# alias source=safely_source

prepend_env() {
    if [[ -z "$1" || -z "$2" ]]; then
        error "$0: At least 2 arguments are required.\nFor example:
        ${INDENT}$0 PATH "$HOME/.local/bin" "/usr/local/bin"\n
        "
        return 1;
    fi

    local env_var_name="$1"
    shift
    local args=("${@}")

    if [[ -z "${(P)env_var_name}" ]]; then
        debug "$0: $env_var_name doesn't exist previously."
        export ${env_var_name}=""
    fi

    for (( i = $#args; i > 0; i-- )); do
        dir=${args[i]}
        if [[ ! -d "$dir" ]]; then
            warning "$0: $dir doesn't exist."
        fi
        if [[ ":${(P)env_var_name}:" != *":$dir:"* ]]; then
            if [[ -z "${(P)env_var_name}" ]]; then
                eval "export ${env_var_name}=\"$dir\""
            else
                eval "export ${env_var_name}=\"$dir:\${${env_var_name}}\""
            fi
        else
            debug "$0: $dir pre-exists in ${env_var_name} and nothing happens."
        fi
    done
}

# TODO: bash-compatiable
append_env() {
    if [[ -z "$1" || -z "$2" ]]; then
        error "$0: At least 2 arguments are required.\nFor example:
        ${INDENT}$0 PATH "$HOME/.local/bin" "/usr/local/bin"
        "
        return 1;
    fi

    local env_var_name="$1"
    shift
    local args=("${@}")

    if [[ -z "${(P)env_var_name}" ]]; then
        debug "$0: $env_var_name doesn't exist previously."
        export ${env_var_name}=""
    fi

    for dir in "${args[@]}"; do
        if [[ ! -d "$dir" ]]; then
            warning "$0: $dir doesn't exist."
        fi
        if [[ ":${(P)env_var_name}:" != *":$dir:"* ]]; then
            if [[ -z "${(P)env_var_name}" ]]; then
                eval "export ${env_var_name}=\"$dir\""
            else
                eval "export ${env_var_name}=\"\${${env_var_name}}:$dir\""
            fi
        else
            warning "$0: $dir pre-exists in ${env_var_name} and nothing happens."
        fi
    done
}

remove_from_env() {
    if [[ -z "$1" || -z "$2" ]]; then
        error "$0: 2 arguments are required.\nFor example:
        ${INDENT}\$ $0 PATH "$HOME/.local/bin"
        "
        return 1;
    fi
    local env_var_name="$1"
    local path_to_remove="$2"
    local current_value="${(P)env_var_name}"

    if [[ ! -d "$path_to_remove" ]]; then
        warning "$0: $path_to_remove doesn't exist."
    fi

    current_value="${current_value//:$path_to_remove:/:}"
    current_value="${current_value//:$path_to_remove/}"
    current_value="${current_value//$path_to_remove:/}"

    if [[ -z $current_value ]]; then
        warning "$0: $1 is unset since it's an empty string now."
        unset $env_var_name
    else
        eval "export ${env_var_name}=\"${current_value}\""
    fi
}

export USER="$USERNAME"
export HOME="${HOME:-/home/$USER}"
export UID="${UID:-$(id -u)}"
export GID="${GID:-$(id -g)}"

export LANG=${LANG:-"en_US.UTF-8"}
export LC_ALL=${LC_ALL:-"en_US.UTF-8"}
export LC_CTYPE=${LC_CTYPE:-"en_US.UTF-8"}

# XDG Directory Specification
# Reference: https://specifications.freedesktop.org/basedir-spec/latest/
export XDG_DATA_HOME=${XDG_DATA_HOME:-"$HOME/.local/share"}
export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-"$HOME/.config"}
export XDG_STATE_HOME=${XDG_STATE_HOME:-"$HOME/.local/state"}
export XDG_CACHE_HOME=${XDG_CACHE_HOME:-"$HOME/.cache"}
export XDG_DATA_DIRS=${XDG_DATA_DIRS:-"/usr/local/share:/usr/share"}
export XDG_CONFIG_DIRS=${XDG_CONFIG_DIRS:-"/etc/xdg"}
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-"/run/user/$(id -u)"}
export XDG_DESKTOP_DIR=${XDG_DESKTOP_DIR:-"$HOME/Desktop"}
export XDG_DOWNLOAD_DIR=${XDG_DOWNLOAD_DIR:-"$HOME/Downloads"}
export XDG_DOCUMENTS_DIR=${XDG_DOCUMENTS_DIR:-"$HOME/Documents"}
export XDG_MUSIC_DIR=${XDG_MUSIC_DIR:-"$HOME/Music"}
export XDG_PICTURES_DIR=${XDG_PICTURES_DIR:-"$HOME/Pictures"}
export XDG_VIDEOS_DIR=${XDG_VIDEOS_DIR:-"$HOME/Videos"}
export XDG_TEMPLATES_DIR=${XDG_TEMPLATES_DIR:-"$HOME/Templates"}
export XDG_PUBLICSHARE_DIR=${XDG_PUBLICSHARE_DIR:-"$HOME/Public"}
# Non-standard XDG variables.
export XDG_PREFIX_HOME="${HOME}/.local"
export XDG_PREFIX_DIR="/usr/local"
# Add XDG vars into envs
prepend_env PATH "${XDG_PREFIX_HOME}/bin" "${XDG_PREFIX_DIR}/bin"
prepend_env LD_LIBRARY_PATH "${XDG_PREFIX_HOME}/lib" "${XDG_PREFIX_DIR}/lib"
prepend_env MANPATH "${XDG_PREFIX_HOME}/man" "${XDG_PREFIX_DIR}/man"
