#!/usr/bin/env bash

UI_LIB="$HOME/.sh_utils/lib/ui.sh"
if [ -f "$UI_LIB" ]; then
    # shellcheck source=lib/ui.sh
    if ! source "$UI_LIB"; then
        echo "error: failed to load ui library"
    fi
else
    echo "error: UI library not found at $UI_LIB"
fi

################################################################################
################################ Handy Commands ################################
################################################################################

has() {
    command -v "$1" 1>/dev/null 2>&1
}

safely_source() {
    if [[ -f "$1" ]]; then
        # shellcheck disable=SC1090
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
        hint "$0: At least 2 arguments are required. Example: $0 PATH $HOME/.local/bin /usr/local/bin"
        return 1
    fi

    local env_var_name="$1"
    shift

    # Read current value of the target env var (works in both bash and zsh)
    local current
    eval "current=\"\${$env_var_name-}\""

    if [[ -z "$current" ]]; then
        debug "$0: $env_var_name doesn't exist previously."
    fi

    # Build the new value by prepending each arg in reverse order
    local newval="$current"
    local i dir
    for (( i=$#; i>=1; i-- )); do
        eval "dir=\${$i}"
        if [[ ! -d "$dir" ]]; then
            debug "$0: $dir doesn't exist."
        fi
        if [[ ":$newval:" != *":$dir:"* ]]; then
            if [[ -n "$newval" ]]; then
                newval="$dir:$newval"
            else
                newval="$dir"
            fi
        else
            debug "$0: $dir pre-exists in ${env_var_name} and nothing happens."
        fi
    done

    # Export the updated value (works in both bash and zsh)
    eval "export ${env_var_name}=\"\$newval\""
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
        hint "$0: At least 2 arguments are required. Example: $0 PATH /usr/local/bin $HOME/.local/bin"
        return 1
    fi

    local env_var_name="$1"
    shift

    # Read current value of the target env var (works in both bash and zsh)
    local current
    eval "current=\"\${$env_var_name-}\""

    if [[ -z "$current" ]]; then
        debug "$0: $env_var_name doesn't exist previously."
    fi

    local newval="$current"
    local i dir
    for (( i=1; i<=$#; i++ )); do
        eval "dir=\${$i}"
        if [[ ! -d "$dir" ]]; then
            debug "$0: $dir doesn't exist."
        fi
        if [[ ":$newval:" != *":$dir:"* ]]; then
            if [[ -n "$newval" ]]; then
                newval="$newval:$dir"
            else
                newval="$dir"
            fi
        else
            debug "$0: $dir pre-exists in ${env_var_name} and nothing happens."
        fi
    done

    # Export the updated value (works in both bash and zsh)
    eval "export ${env_var_name}=\"\$newval\""
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
        hint "$0: Two arguments are required. Example: $0 PATH $HOME/.local/bin"
        return 1
    fi
    local env_var_name="$1"
    local path_to_remove="$2"
    local current_value
    eval "current_value=\"\${$env_var_name-}\""

    if [[ ! -d "$path_to_remove" ]]; then
        debug "$0: $path_to_remove doesn't exist."
    fi

    # Remove all occurrences as a distinct path segment
    local padded=":$current_value:"
    padded="${padded//:$path_to_remove:/:}"
    # Trim leading/trailing colon
    padded="${padded#:}"
    padded="${padded%:}"
    current_value="$padded"

    if [[ -z "$current_value" ]]; then
        debug "$0: $1 is unset since it's an empty string now."
        eval "unset ${env_var_name}"
    else
        eval "export ${env_var_name}=\"\$current_value\""
    fi
}

# Add XDG vars into envs
prepend_env PATH "${XDG_PREFIX_HOME}/bin" "${XDG_PREFIX_DIR}/bin"
prepend_env LD_LIBRARY_PATH "${XDG_PREFIX_HOME}/lib" "${XDG_PREFIX_DIR}/lib"
prepend_env MANPATH "${XDG_PREFIX_HOME}/man" "${XDG_PREFIX_DIR}/man"
