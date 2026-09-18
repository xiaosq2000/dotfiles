#!/usr/bin/env zsh

if ! type safely_source >/dev/null 2>&1; then
    source ~/.sh_utils/basics.sh
fi

_sh_utils_source_tool() {
    if type safely_source >/dev/null 2>&1; then
        safely_source "$1"
    elif [ -r "$1" ]; then
        source "$1"
    else
        printf 'warning: %s is not found.\n' "$1" >&2
    fi
}

_SH_UTILS_TOOLS_DIR="$HOME/.sh_utils/tools"
_sh_utils_source_tool "$_SH_UTILS_TOOLS_DIR/notifications.sh"
_sh_utils_source_tool "$_SH_UTILS_TOOLS_DIR/image_convert.sh"
_sh_utils_source_tool "$_SH_UTILS_TOOLS_DIR/image_process.sh"
_sh_utils_source_tool "$_SH_UTILS_TOOLS_DIR/pdf.sh"
_sh_utils_source_tool "$_SH_UTILS_TOOLS_DIR/video_convert.sh"
_sh_utils_source_tool "$_SH_UTILS_TOOLS_DIR/video_process.sh"
_sh_utils_source_tool "$_SH_UTILS_TOOLS_DIR/audio.sh"
_sh_utils_source_tool "$_SH_UTILS_TOOLS_DIR/media_utils.sh"
unset _SH_UTILS_TOOLS_DIR

if type unfunction >/dev/null 2>&1; then
    unfunction _sh_utils_source_tool
else
    unset -f _sh_utils_source_tool
fi
