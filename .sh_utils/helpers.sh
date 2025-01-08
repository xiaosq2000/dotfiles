#!/usr/env/bin bash

sync() {
    git pull
    git add .
    if [[ -z "$1" ]]; then
        git commit -m "Update"
    else
        git commit -m "$1"
    fi
    git push
}

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
        if read -qs "?Do you want to proceed and replace everything? (y/N)"; then
            >&2 echo -e "\nYour choice: $REPLY"
        else 
            >&2 echo -e "\nYour choice: $REPLY"
            return 0;
        fi
    fi
    # Install
    (cd ${SRC_DIR} && find . -type f -exec install -Dm 755 "{}" "${DEST_DIR}/{}" \;)
    # Generate install_manifest
    find ${SRC_DIR} -type f -exec echo "{}" > "$INSTALL_MANIFEST" \;
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
    sudo <$INSTALL_MANIFEST xargs -I % rm % 
    if [[ -d "${DEST_DIR}" ]]; then
        debug "Remove empty folders in ${DEST_DIR}"
        sudo find ${DEST_DIR} -type d -empty -delete
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
    ssh $host -t "zsh -ic \"tmux a || tmux new -s '$session_name'\""
}

# Let each shell open a tmux session
auto_tmux() {
    if has "tmux" && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
        exec tmux
    fi
}

enter_docker_container() {
    if has "docker"; then
        ;
    else
        error "docker: command not found.";
        return 1;
    fi
    docker exec -it $1 zsh
}

set_ros() {
    if [[ -n ${ROS1_DISTRO} && -f "/opt/ros/${ROS1_DISTRO}/setup.zsh" ]]; then
        source "/opt/ros/${ROS1_DISTRO}/setup.zsh";
        info "Using ROS $BOLD$ROS_DISTRO$RESET.";
    fi
}

set_ros2() {
    if [[ -n ${ROS2_DISTRO} && -f "/opt/ros/${ROS2_DISTRO}/setup.zsh" ]]; then
        source "/opt/ros/${ROS2_DISTRO}/setup.zsh";
        info "Using ROS2 $BOLD$ROS_DISTRO$RESET.";
        printf "%s\n" "
ROS2 Environment Variables:
${INDENT}ROS_VERSION=${ROS_VERSION}
${INDENT}ROS_PYTHON_VERSION=${ROS_PYTHON_VERSION}
${INDENT}ROS_DISTRO=${ROS_DISTRO}
${INDENT}ROS_DOMAIN_ID=${ROS_DOMAIN_ID}
${INDENT}ROS_LOCALHOST_ONLY=${ROS_LOCALHOST_ONLY}
        "
        debug "Setup colcon_cd"
        source "/usr/share/colcon_cd/function/colcon_cd.sh"
        export _colcon_cd_root="/opt/ros/${ROS_DISTRO}"
        debug "Setup colcon tab completion"
        [ -f "/usr/share/colcon_argcomplete/hook/colcon-argcomplete.zsh" ] && source "/usr/share/colcon_argcomplete/hook/colcon-argcomplete.zsh"
    fi
}

help() {
    echo "
${BOLD}${BLUE}Supported Commands${RESET}:
    
+-----------------+
| System Overview |
+-----------------+

${INDENT}hardware_overview
${INDENT}software_overview

${INDENT}display_xdg_envs
${INDENT}display_typefaces

${INDENT}check_x11_wayland
${INDENT}check_git_config

+------------+
| Networking |
+------------+

${INDENT}check_public_ip
${INDENT}check_private_ip
${INDENT}set_proxy
${INDENT}unset_proxy
${INDENT}check_proxy_status
${INDENT}check_port_availability

+----------------------+
| Other Handy Commands |
+----------------------+

${INDENT}prepend_env
${INDENT}append_env
${INDENT}remove_from_env

${INDENT}manual_install 
${INDENT}manual_uninstall

${INDENT}set_ros 
${INDENT}set_ros2

${INDENT}command_with_email_notification \"<COMMAND>\"

${INDENT}sync

${INDENT}compress_pdf <INPUT_FILE> <OUTPUT_FILE>
${INDENT}svg2pdf <FILENAME_WITHOUT_EXTENSION>
${INDENT}webp2png <FILENAME_WITHOUT_EXTENSION>
${INDENT}webm2mp4 <FILENAME_WITHOUT_EXTENSION>
${INDENT}gif2mp4 <FILENAME_WITHOUT_EXTENSION>
${INDENT}mp42png <FILENAME_WITHOUT_EXTENSION>
"
}

