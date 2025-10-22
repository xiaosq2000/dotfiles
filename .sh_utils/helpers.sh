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

_guess_ros_distro() {
    local count=0
    local last=""
    if [ -d /opt/ros ]; then
        while IFS= read -r dir; do
            last=$(basename "$dir")
            count=$((count+1))
        done < <(find /opt/ros -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
    fi
    if [ "$count" -eq 1 ] && [ -n "$last" ]; then
        printf "%s" "$last"
        return 0
    fi
    return 1
}

setup_ros() {
    if [[ -z ${ROS1_DISTRO} ]]; then
        local __guess
        __guess=$(_guess_ros_distro) || true
        if [[ -n ${__guess} ]]; then
            export ROS1_DISTRO="${__guess}"
            hint "please specify environment variable \"ROS1_DISTRO\""
            hint "make a guess here: ROS1_DISTRO=${ROS1_DISTRO}"
        fi
    fi
    if [[ -n ${ROS1_DISTRO} && -f "/opt/ros/${ROS1_DISTRO}/setup.zsh" ]]; then
        # shellcheck source=/dev/null
        source "/opt/ros/${ROS1_DISTRO}/setup.zsh";
        msg "${BOLD}${UNDERLINE}${ICON_ROS}ROS $ROS1_DISTRO${RESET}";
    else
        hint "make sure ROS is ready; please specify environment variable \"ROS1_DISTRO\""
    fi
}

setup_ros2() {
    if [[ -z ${ROS2_DISTRO} ]]; then
        local __guess
        __guess=$(_guess_ros_distro) || true
        if [[ -n ${__guess} ]]; then
            export ROS2_DISTRO="${__guess}"
            hint "please specify environment variable \"ROS2_DISTRO\""
            hint "make a guess here: ROS2_DISTRO=${ROS2_DISTRO}"
        fi
    fi
    if [[ -n ${ROS2_DISTRO} && -f "/opt/ros/${ROS2_DISTRO}/setup.zsh" ]]; then
        msg "${BOLD}${UNDERLINE}${ICON_ROS}ROS 2 $ROS2_DISTRO${RESET}";
        # shellcheck source=/dev/null
        source "/opt/ros/${ROS2_DISTRO}/setup.zsh";
        info "ROS2 Environment Variables:"
        info "ROS_VERSION=${ROS_VERSION}"
        info "ROS_PYTHON_VERSION=${ROS_PYTHON_VERSION}"
        # shellcheck disable=SC2153
        info "ROS_DISTRO=${ROS_DISTRO}"
        info "ROS_DOMAIN_ID=${ROS_DOMAIN_ID}"
        info "ROS_LOCALHOST_ONLY=${ROS_LOCALHOST_ONLY}"
        if [ -f "/usr/share/colcon_cd/function/colcon_cd.sh" ]; then
            source "/usr/share/colcon_cd/function/colcon_cd.sh"
            export _colcon_cd_root="/opt/ros/${ROS_DISTRO}"
            success "colcon_cd"
        else
            warning "colcon_cd not found."
            hint "try 'sudo apt install python3-colcon-common-extensions'"
        fi
        if [ -f "/usr/share/colcon_argcomplete/hook/colcon-argcomplete.zsh" ]; then
            source "/usr/share/colcon_argcomplete/hook/colcon-argcomplete.zsh"
            success "colcon-argcomplete"
        else
            warning "colcon-argcomplete.zsh not found."
            hint "try 'sudo apt install python3-colcon-common-extensions'"
        fi
    else
        hint "make sure ROS2 is ready; please specify environment variable \"ROS2_DISTRO\""
    fi
}

setup_texlive() {
    TEXLIVE_VERSION=2025
    if [[ -d "${XDG_DATA_HOME}/../texlive/${TEXLIVE_VERSION}/bin/x86_64-linux" ]]; then
        append_env PATH "${XDG_DATA_HOME}/../texlive/${TEXLIVE_VERSION}/bin/x86_64-linux"
        debug "using Texlive $TEXLIVE_VERSION"
    elif [[ -d "${XDG_PREFIX_DIR}/texlive/${TEXLIVE_VERSION}" ]]; then
        append_env PATH "${XDG_PREFIX_DIR}/texlive/${TEXLIVE_VERSION}/texmf-dist/doc/info"
        append_env PATH "${XDG_PREFIX_DIR}/texlive/${TEXLIVE_VERSION}/texmf-dist/doc/man"
        append_env PATH "${XDG_PREFIX_DIR}/texlive/${TEXLIVE_VERSION}/bin/x86_64-linux"
        debug "using Texlive $TEXLIVE_VERSION"
    else
        debug "Texlive $TEXLIVE_VERSION not found"
    fi
}
