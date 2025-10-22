#!/usr/bin/env bash

manual_install() {
    SRC_DIR=${1%/}
    DEST_DIR=${2:-${XDG_PREFIX_HOME}}
    INSTALL_MANIFEST=${3:-install_manifest.txt}
    if [[ "$#" == 0 ]]; then
        printf "%s" "Usage:

    $0 SRC_DIR [DEST_DIR] [INSTALL_MANIFEST]

Default:

    $0 SRC_DIR ${DEST_DIR} ${INSTALL_MANIFEST}
        "
        return 1;
    fi
    if [[ ! -d ${SRC_DIR} ]]; then
        error "${SRC_DIR} is not found."
        return 1;
    fi
    if [[ ! -d ${DEST_DIR} ]]; then
        error "${DEST_DIR} is not found."
        return 1;
    fi
    if [[ -f ${INSTALL_MANIFEST} ]]; then
        warning "${INSTALL_MANIFEST} exists."
        # ref: https://unix.stackexchange.com/a/565636
        if read -qrs "?Do you want to proceed and replace everything? (y/N)"; then
            >&2 echo -e "\nYour choice: $REPLY"
        else
            >&2 echo -e "\nYour choice: $REPLY"
            return 0;
        fi
    fi
    # Install
    (cd "${SRC_DIR}" && find . -type f -exec install -Dm 755 "{}" "${DEST_DIR}/{}" \;)
    # Generate install_manifest
    (cd "${SRC_DIR}" && find . -type f -printf "%p\n") > "$INSTALL_MANIFEST"
    sed -i "s|^.|${DEST_DIR}|" "$INSTALL_MANIFEST"
    completed "Done."
}

manual_uninstall() {
    if [[ "$#" == 0 ]]; then
        printf "%s" "Usage:

    $0 INSTALL_MANIFEST DEST_DIR
        "
        return 1;
    fi
    INSTALL_MANIFEST=${1}
    DEST_DIR=${2}
    if [[ ! -f "${INSTALL_MANIFEST}" ]]; then
        error "${INSTALL_MANIFEST} is not found."
        return 1;
    fi
    cat "$INSTALL_MANIFEST" | xargs -I % rm %
    if [[ -d "${DEST_DIR}" ]]; then
        debug "Remove empty folders in ${DEST_DIR}"
        find "${DEST_DIR}" -type d -empty -delete
    fi
    info "You could remove the file ${BOLD}${INSTALL_MANIFEST}${RESET} manually."
    completed "Done."
}

sshtmux() {
    host="$1";
    if [[ -n "$2" ]]; then
        session_name="$2";
    else
        session_name="session-$(date +%d/%m/%y)";
    fi
    ssh "$host" -t "zsh -ic \"tmux a || tmux new -s '$session_name'\""
}

# Let each shell open a tmux session
auto_tmux() {
    if has "tmux" && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
        exec tmux
    fi
}
