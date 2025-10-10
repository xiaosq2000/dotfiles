#!/usr/env/bin bash

################################################################################
###################################### UX ######################################
################################################################################

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

# Detect Nerd Font support
has_nerd_font() {
    # Check if terminal supports UTF-8
    if [[ "$LANG" != *"UTF-8"* ]] && [[ "$LC_ALL" != *"UTF-8"* ]]; then
        return 1
    fi

    # Check for known terminals/fonts that support Nerd Fonts
    if [[ -n "$KITTY_WINDOW_ID" ]] || \
        [[ -n "$ALACRITTY_SOCKET" ]] || \
        [[ -n "$WEZTERM_EXECUTABLE" ]] || \
        [[ "$TERM_PROGRAM" == "iTerm.app" ]] || \
        [[ "$TERM_PROGRAM" == "WezTerm" ]] || \
        [[ "$TERM" == *"kitty"* ]] || \
        [[ "$TERM" == *"alacritty"* ]]; then
        return 0
    fi

    # Check if a Nerd Font is explicitly set
    if [[ -n "$NERD_FONT" ]] || [[ "$USE_NERD_FONT" == "true" ]]; then
        return 0
    fi

    return 1
}

# Set icons based on Nerd Font support
if has_nerd_font; then
    ICON_ERROR="󰅚 "
    ICON_WARNING="󰀪 "
    ICON_INFO="󰋽 "
    ICON_DEBUG="󰃤 "
    ICON_SUCCESS="󰄬 "
else
    ICON_ERROR=""
    ICON_WARNING=""
    ICON_INFO=""
    ICON_DEBUG=""
    ICON_SUCCESS=""
fi

error() {
    printf '%s\n' "${BOLD}${RED}${ICON_ERROR}error:${RESET} $*" >&2
}
warning() {
    printf '%s\n' "${BOLD}${YELLOW}${ICON_WARNING}warning:${RESET} $*"
}
info() {
    printf '%s\n' "${BOLD}${BLUE}${ICON_INFO}info:${RESET} $*"
}
debug() {
    local debug_enabled=false
    for var in DEBUG debug VERBOSE verbose; do
        eval "local value=\"\$$var\""
        case "$value" in
            [Tt][Rr][Uu][Ee]|1|[Oo][Nn]|[Yy][Ee][Ss])
                debug_enabled=true
                break
                ;;
        esac
    done
    if [ "$debug_enabled" = "true" ]; then
        printf '%s\n' "${BOLD}${ICON_DEBUG}debug:${RESET} $*"
    fi
}
completed() {
    printf '%s\n' "${BOLD}${GREEN}${ICON_SUCCESS}success:${RESET} $*"
}

################################################################################
################################ Handy Commands ################################
################################################################################

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

################################################################################
############################ Environment Variables #############################
################################################################################

export USER="${USER:-$(id -un)}"
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

# Non-standard XDG variables
export XDG_PREFIX_HOME="${HOME}/.local"
export XDG_PREFIX_DIR="/usr/local"

# prepend_env VAR_NAME DIR1 [DIR2 ...]
# Prepend one or more directories to the given environment variable.
# - Maintains the order of arguments (DIR1 comes before DIR2, etc.).
# - Skips adding a directory if it's already present as a distinct path segment.
# - Adds directories even if they don't exist on disk; a debug message is printed in that case.
# - Creates the variable if it doesn't already exist.
# Example:
#   prepend_env PATH "$HOME/.local/bin" "/usr/local/bin"
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
            debug "$0: $dir doesn't exist."
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

# append_env VAR_NAME DIR1 [DIR2 ...]
# Append one or more directories to the given environment variable.
# - Maintains the order of arguments (DIR1 comes before DIR2, etc.).
# - Skips adding a directory if it's already present as a distinct path segment.
# - Adds directories even if they don't exist on disk; a debug message is printed in that case.
# - Creates the variable if it doesn't already exist.
# Example:
#   append_env PATH "/usr/local/bin" "$HOME/.local/bin"
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
            debug "$0: $dir doesn't exist."
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

# remove_from_env VAR_NAME PATH_TO_REMOVE
# Remove a directory from the given environment variable (all occurrences).
# - Matches whole path segments; safe for colon-separated variables like PATH, LD_LIBRARY_PATH, MANPATH.
# - Unsets the variable if it becomes empty after removal.
# - Does not error if the directory does not exist or is not present in the variable.
# Example:
#   remove_from_env PATH "$HOME/.local/bin"
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
        debug "$0: $path_to_remove doesn't exist."
    fi

    current_value="${current_value//:$path_to_remove:/:}"
    current_value="${current_value//:$path_to_remove/}"
    current_value="${current_value//$path_to_remove:/}"

    if [[ -z $current_value ]]; then
        debug "$0: $1 is unset since it's an empty string now."
        unset $env_var_name
    else
        eval "export ${env_var_name}=\"${current_value}\""
    fi
}

# Add XDG vars into envs
prepend_env PATH "${XDG_PREFIX_HOME}/bin" "${XDG_PREFIX_DIR}/bin"
prepend_env LD_LIBRARY_PATH "${XDG_PREFIX_HOME}/lib" "${XDG_PREFIX_DIR}/lib"
prepend_env MANPATH "${XDG_PREFIX_HOME}/man" "${XDG_PREFIX_DIR}/man"
