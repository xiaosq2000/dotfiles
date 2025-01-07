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
