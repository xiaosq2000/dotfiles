#!/usr/bin/env zsh
zshrc_start_time=$(date +%s%N)

# load modules and slurm
# [ -f "/etc/profile.d/modules.sh" ] && source "/etc/profile.d/modules.sh" && module load slurm
#
export USER=$USERNAME
# ":-" in Bash,
# ref: https://unix.stackexchange.com/a/282816
export LANG=${LANG:-"en_US.UTF-8"}
export LC_ALL=${LC_ALL:-"en_US.UTF-8"}
export LC_CTYPE=${LC_CTYPE:-"en_US.UTF-8"}
# XDG Base Directory Specification,
# ref: https://specifications.freedesktop.org/basedir-spec/latest/
export XDG_DATA_HOME=${XDG_DATA_HOME:-"$HOME/.local/share"}
export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-"$HOME/.config"}
export XDG_STATE_HOME=${XDG_STATE_HOME:-"$HOME/.local/state"}
export XDG_CACHE_HOME=${XDG_CACHE_HOME:-"$HOME/.cache"}
export XDG_DATA_DIRS=${XDG_DATA_DIRS:-"/usr/local/share:/usr/share"}
export XDG_CONFIG_DIRS=${XDG_CONFIG_DIRS:-"/etc/xdg"}
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-"/run/user/$(id -u)"}
# non-standard variables
export XDG_PREFIX_HOME="${HOME}/.local"
export XDG_PREFIX_DIR="/usr/local"

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

# TODO: bash-compatiable
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

prepend_env PATH "${XDG_PREFIX_HOME}/bin" "${XDG_PREFIX_DIR}/bin"
prepend_env LD_LIBRARY_PATH "${XDG_PREFIX_HOME}/lib" "${XDG_PREFIX_DIR}/lib"
prepend_env MANPATH "${XDG_PREFIX_HOME}/man" "${XDG_PREFIX_DIR}/man"

check_public_ip() {
    local ipinfo=$(curl --silent ipinfo.io)
    if [[ -z "$ipinfo" ]]; then
        error "No public networking."
    else
        echo -e "${MAGENTA}Public Network:${RESET}\n${INDENT}$(echo $ipinfo | grep --color=never -e '\"ip\"' -e '\"city\"' | sed 's/^[ \t]*//' | awk '{print}' ORS=' ')"
    fi
    echo
}
check_private_ip() {
    echo -e "${MAGENTA}Private Network:${RESET}\n${INDENT}\"ip\": \"$(hostname -I | awk '{ print $1; }')\","
    echo
}
check_all_private_ip() {
    echo -e "${MAGENTA}Private Network:${RESET}\n${INDENT}\"ip\": \"$(hostname -I | head -c -1 | sed 's/ /, /g')\""
    echo
}
proxy_protocol="trojan"
set_proxy() {
    if [[ $(uname -r | grep 'WSL2') ]]; then
        warning "Make sure the VPN client is working on host."
        local host="'$(ip route show | grep -i default | awk '{ print $3}')'"
        local port=1080
    elif [ -f /.dockerenv ]; then
        warning "It's a docker container. only \"host\" networking mode is supported."
        local host="'127.0.0.1'"
        local port=1080
    else
        if [[ $(lsb_release -d | grep 'Ubuntu') ]]; then
            local host="'127.0.0.1'"
            local port=1080
            debug "Start the VPN client service."
            sudo systemctl start sing-box-${proxy_protocol}.service
            sleep 5s;
            debug "Set GNOME networking proxy settings."
            dconf write /system/proxy/mode "'manual'"
            dconf write /system/proxy/http/host ${host}
            dconf write /system/proxy/http/port ${port}
            dconf write /system/proxy/https/host ${host}
            dconf write /system/proxy/https/port ${port}
            dconf write /system/proxy/ftp/host ${host}
            dconf write /system/proxy/ftp/port ${port}
            dconf write /system/proxy/socks/host ${host}
            dconf write /system/proxy/socks/port ${port}
            dconf write /system/proxy/ignore-hosts "'localhost,127.0.0.0/8,::1'"
        else
            error "This platform is not supported."
        fi
    fi
    debug "Set environment variables and configure for specific programs."
    local host="${host//\'/}"
    local port="${port}"
    export http_proxy=${http_proxy:-"${host}:${port}"}
    export https_proxy=${https_proxy:-"${host}:${port}"}
    export ftp_proxy=${ftp_proxy:-"${host}:${port}"}
    export socks_proxy=${socks_proxy:-"${host}:${port}"}
    export no_proxy=${no_proxy:-"localhost,127.0.0.0/8,::1"}
    export HTTP_PROXY=${HTTP_PROXY:-${http_proxy}}
    export HTTPS_PROXY=${HTTPS_PROXY:-${https_proxy}}
    export FTP_PROXY=${FTP_PROXY:-${ftp_proxy}}
    export SOCKS_PROXY=${SOCKS_PROXY:-${socks_proxy}}
    export NO_PROXY=${NO_PROXY:-${no_proxy}}
    debug "Set git global network proxy."
    git config --global http.proxy ${http_proxy}
    git config --global https.proxy ${https_proxy}
    # info "You're recommended to wait a couple of seconds until the VPN client is on.

    #   Try with:

    #   ${INDENT}$ VERBOSE=true check_proxy_status

    #   or

    #   ${INDENT}$ check_public_ip
    # "
    check_public_ip;
}
unset_proxy() {
    if [[ ! $(uname -r | grep 'WSL2') && ! -f /.dockerenv ]]; then
        if [[ $(lsb_release -d | grep 'Ubuntu') ]]; then
            debug "Stop VPN client service."
            sudo systemctl stop sing-box-${proxy_protocol}.service
            debug "Unset GNOME networking proxy settings."
            dconf write /system/proxy/mode "'none'"
        else
            error "Unsupported for this platform."
        fi
    fi
    debug "Unset environment variables."
    unset http_proxy
    unset https_proxy
    unset HTTP_PROXY
    unset HTTPS_PROXY
    unset ftp_proxy
    unset FTP_PROXY
    unset socks_proxy
    unset SOCKS_PROXY
    unset all_proxy
    unset ALL_PROXY
    unset no_proxy
    unset NO_PROXY
    debug "Unset git global network proxy."
    git config --global --unset http.proxy
    git config --global --unset https.proxy
    # info "Try with:

    #   ${INDENT}$ VERBOSE=true check_proxy_status

    #   or

    #   ${INDENT}$ check_public_ip
    # "
    check_public_ip
}
check_proxy_status() {
    local proxy_env=$(env | grep --color=never -i 'proxy')
    if [[ -n $proxy_env ]]; then
        info "The shell is using network proxy.";
    else
        info "The shell is ${BOLD}${YELLOW}NOT${RESET} using network proxy.";
    fi
    echo
    check_public_ip;
    echo "${CYAN}Environment Variables Related with Network Proxy: ${RESET}"
    echo $proxy_env | while read line; do echo "${INDENT}${line}"; done
    echo
    echo "${YELLOW}VPN Client Status: ${RESET}"
    if [[ $(uname -r | grep 'WSL2') ]]; then
        warning "Unknown. For WSL2, the VPN client is probably running on the host machine. Please check manually.";
    elif [[ -f /.dockerenv ]]; then
        warning "Unknown. For a Docker container, the VPN client is probably running on the host machine. Please check manually.";
    else
        echo "${INDENT}$(systemctl is-active sing-box-${proxy_protocol}.service)"
    fi
    echo
}

check_port_availability() {
    if [[ -z $1 ]]; then
        error "An argument, the port number, should be given."
        return 1;
    fi
    if [[ $(sudo ufw status | head -n 1 | awk '{ print $2;}') == "active" ]]; then
        info "ufw is active.";
        if [[ -z $(sudo ufw status | grep "$1") ]]; then
            warning "port $1 is not specified in the firewall rules and may not be allowed to use.";
        else
            sudo ufw status | grep "$1"
        fi
    else
        info "ufw is inactive.";
    fi
    if [[ -z $(sudo lsof -i:$1) ]]; then
        info "port $1 is not in use.";
    else
        error "port $1 is ${BOLD}unavaiable${RESET}.";
    fi
}

has() {
  command -v "$1" 1>/dev/null 2>&1
}

# Preferred editor
if has "nvim"; then
    export SUDO_EDITOR='nvim'
    export EDITOR='nvim'
    alias v='nvim'
    if has "git"; then
        git config --global core.editor "nvim"
    fi
elif has "vim"; then
    export SUDO_EDITOR='vim'
    export EDITOR='vim'
    alias v='vim'
    if has "git"; then
        git config --global core.editor "vim"
    fi
elif has "vi"; then
    export SUDO_EDITOR='vi'
    export EDITOR='vi'
    alias v='vi'
    if has "git"; then
        git config --global core.editor "vi"
    fi
fi

# Compilation
export ARCHFLAGS="-arch $(uname -m)"
export NUMCPUS=$(grep -c '^processor' /proc/cpuinfo)
alias pmake='time nice make -j${NUMCPUS} --load-average=${NUMCPUS}'

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
alias python="python3"
alias lg="lazygit"
alias ohmyzsh="${EDITOR} ${HOME}/.oh-my-zsh"
alias zshconfig="${EDITOR} ${HOME}/.zshrc"
alias nvimconfig="${EDITOR} ${XDG_CONFIG_HOME}/nvim"
alias tmuxconfig="${EDITOR} ${XDG_CONFIG_HOME}/tmux"
alias sshconfig="${EDITOR} ${HOME}/.ssh/config"
alias starshipconfig="${EDITOR} ${XDG_CONFIG_HOME}/starship.toml"
alias alacrittyconfig="${EDITOR} $XDG_CONFIG_HOME/alacritty/alacritty.toml"
export NVM_DIR="${XDG_CONFIG_HOME}/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm

eval "$(starship init zsh)"

# >>> personal miniconda initialization >>>
__conda_setup="$("${XDG_PREFIX_HOME}/miniconda3/bin/conda" 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "${XDG_PREFIX_HOME}/miniconda3/etc/profile.d/conda.sh" ]; then
        . "${XDG_PREFIX_HOME}/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="${XDG_PREFIX_HOME}/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< personal miniconda initialization <<<

# micromamba is preferred rather than miniconda
# >>> personal micromamba initialization >>>
export MAMBA_EXE="${XDG_PREFIX_HOME}/bin/micromamba";
export MAMBA_ROOT_PREFIX="${XDG_DATA_HOME}/micromamba";
__mamba_setup="$("$MAMBA_EXE" shell hook --shell zsh --root-prefix "$MAMBA_ROOT_PREFIX" 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__mamba_setup"
    alias conda=micromamba
else
    alias micromamba="$MAMBA_EXE"  # Fallback on help from mamba activate
    alias conda="$MAMBA_EXE"       # Fallback on help from mamba activate
fi
unset __mamba_setup
# <<< personal micromamba initialization <<<
#
# Rust
if [[ -f "$HOME/.cargo/env" ]]; then
    . "$HOME/.cargo/env"
fi

software_overview() {
    exec 2> /dev/null
    echo "${BLUE}Software Overview: ${RESET}"
    local WIDTH=16
    software_overview_helper() {
        local format="${INDENT}%-${WIDTH}s%s\n";
        local not_found_format="${INDENT}${BOLD}${RED}%-${WIDTH}s%s${RESET}\n";
        local cli_name;
        local version;
        if [[ $# -eq 3 ]]; then
            format=$1;
            cli_name=$2;
            version=$3;
        elif [[ $# -eq 2 ]]; then
            cli_name=$1;
            version=$2;
        else
            error "Given $# arguments, it should be 2 or 3."
            return 1;
        fi
        local unaliased_name;
        local print_only_not_found="false";
        if [[ $(which $cli_name | grep 'alias') ]]; then
            unaliased_name="$(which $cli_name | awk '{ print $4; }')";
        else
            unaliased_name="$cli_name";
        fi
        if has "$unaliased_name"; then
            if [[ ! $print_only_not_found == "true" ]]; then
                printf "$format" "$unaliased_name" "$version";
            fi
        else
            printf "$not_found_format" "$unaliased_name" "not found";
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
    software_overview_helper "cmake" "$(cmake --version | head -n 1 | awk '{ print $3; }')"
    software_overview_helper "ninja" "$(ninja --version)"
    software_overview_helper "cargo" "$(cargo --version | awk '{ print $2; }')"
    software_overview_helper "python" "$(python --version | awk '{ print $2; }')"
    software_overview_helper "conda" "$(conda --version | awk '{ print $2; }')"
    software_overview_helper "mamba" "$(mamba --version)"
    software_overview_helper "micromamba" "$(micromamba --version)"
    software_overview_helper "gnome-shell" "$(gnome-shell --version | awk '{ print $3; }')"
    software_overview_helper "gnome-terminal" "$(gnome-terminal --version | awk '{ print $4; }')"
    software_overview_helper "alacritty" "$(alacritty --version | awk '{ print $2; }')"
    software_overview_helper "xclip" "$(xclip -version 2>&1 | head -n 1 | awk '{ print $3;}')"
    software_overview_helper "zathura" "$(zathura --version | head -n 1 | awk '{ print $2; }')"
    software_overview_helper "TeX" "$(tex --version | grep -o '(.*)' | sed 's/[()]//g')"
    if [ -z "${ROS_DISTRO}" ]; then
        software_overview_helper "${INDENT}${RED}%-${WIDTH}s${RESET}%s\n" "ROS" "not found"
    else
        software_overview_helper "${INDENT}${GREEN}%-${WIDTH}s${RESET}%s\n" "ROS" "${ROS_DISTRO}"
    fi
    echo
    unfunction software_overview_helper
    exec 2> /dev/tty
}

hardware_overview() {
    local WIDTH=32
    hardware_overview_helper() {
        printf "${INDENT}%-${WIDTH}s${RESET}%s\n" "$1" "$2"
    }
    echo "${BLUE}Hardware Overview:${RESET}"
    hardware_overview_helper "CPU Device:" "$(cat /proc/cpuinfo | grep ^'model name' | sed -n '1p' | grep -oP '(?<=: ).*')"
    hardware_overview_helper "CPU Processing Units:" "$(nproc --all)"
    if [ -f "/proc/driver/nvidia/version" ]; then
        if [ ! -x "$(command -v nvidia-smi)" ]; then
            error "command \"nvidia-smi\" not found."
        else
            hardware_overview_helper "NVIDIA GPU Device:" "$(nvidia-smi -L | sed 's/([^)]*)//g')"
        fi
        hardware_overview_helper "NVIDIA Driver Version:" "$(grep -oP 'NVRM version:\s+NVIDIA UNIX\s+\S+\s+Kernel Module\s+\K[0-9.]+' /proc/driver/nvidia/version)"
    else
        error "NVIDIA Driver not found."
    fi
    hardware_overview_helper "Available Memory:" "$(free -mh | grep ^Mem | awk '{ print $7; }')/$(free -mh | grep ^Mem | awk '{ print $2; }')"
    if [[ ! $(uname -r | grep 'WSL2') && ! -f /.dockerenv ]]; then
        hardware_overview_helper "Available Storage:" "$(df -h --total | grep --color=never 'total' | awk '{ print $4 }')/$(df -h --total | grep --color=never 'total' | awk '{ print $2 }')"
    else
        # the results of 'total' field will be doubled if inside a docker container.
        hardware_overview_helper "Available Storage:" "$(df -h --total | grep --color=never '/etc/hosts' | awk '{ print $4 }')/$(df -h --total | grep --color=never '/etc/hosts' | awk '{ print $2 }')"
    fi
    echo
    unfunction hardware_overview_helper
}

check_git_config () {
    if has "git"; then
        if [[ ! -f $HOME/.gitconfig ]]; then
            touch $HOME/.gitconfig
        fi
        if [[ ! $(cat $HOME/.gitconfig | grep 'email') ]]; then
            warning "You are recommended to execute:
    
    ${INDENT}git config --global user.email \"<YOUR_EMAIL>\"
    "
        fi
        if [[ ! $(cat $HOME/.gitconfig | grep 'name') ]]; then
            warning "You are recommended to execute:
    
    ${INDENT}git config --global user.name \"<YOUR_NAME>\"
    "
        fi
    fi
}

display_typefaces() {
    # ref: https://stackoverflow.com/a/49313231/11393911
    fc-list -f "%{family}\n" | grep -i "$1" | sort -t: -u -k1,1
    if [ -z $1 ]; then
        info "A hint of the typeface family name could be given as an argument.
        For example:
            $0 fira
        "
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
alias latex='enter_docker_container latex'
robotics(){
    if [[ -z "$1" ]]; then
        enter_docker_container robotics
    else 
        enter_docker_container robotics-"$1"
    fi
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

################################################################################
CASE_SENSITIVE="false"

HYPHEN_INSENSITIVE="true"

zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

export ZSH="$HOME/.oh-my-zsh"
HIST_STAMPS="dd/mm/yyyy"

ZSH_CUSTOM=${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}

download_plugins() {
    if [[ ! -d "${ZSH_CUSTOM}/plugins/conda-zsh-completion" ]]; then
        git clone --depth 1 https://github.com/conda-incubator/conda-zsh-completion "${ZSH_CUSTOM}/plugins/conda-zsh-completion"
    fi
    if [[ ! -d "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting" ]]; then
        git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting"
    fi
    if [[ ! -d "${ZSH_CUSTOM}/plugins/zsh-autosuggestions" ]]; then
        git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions.git "${ZSH_CUSTOM}/plugins/zsh-autosuggestions"
    fi
    if [[ ! -d "${ZSH_CUSTOM}/plugins/zsh-autoenv" ]]; then
        git clone --depth 1 https://github.com/Tarrasch/zsh-autoenv "${ZSH_CUSTOM}/plugins/zsh-autoenv"
    fi
    if [[ ! -d "${ZSH_CUSTOM}/plugins/zsh-vi-mode" ]]; then
        git clone --depth 1 https://github.com/jeffreytse/zsh-vi-mode "${ZSH_CUSTOM}/plugins/zsh-vi-mode"
    fi
    if [[ ! -d "${XDG_DATA_HOME}/tmux/plugins/catppuccin/tmux" ]]; then
        git clone --depth 1 https://github.com/catppuccin/tmux.git ${XDG_DATA_HOME}/tmux/plugins/catppuccin/tmux
    fi
}
download_plugins

source "${XDG_CONFIG_HOME}/zsh/catppuccin_latte-zsh-syntax-highlighting.zsh"
source "${ZSH_CUSTOM}/plugins/zsh-autoenv/autoenv.zsh"
# Only changing the escape key to `jk` in insert mode, we still
# keep using the default keybindings `^[` in other modes
ZVM_VI_INSERT_ESCAPE_BINDKEY=jk
plugins=(
    git
    git-auto-fetch
    docker
    docker-compose
    # The following are manually installed plugins
    conda-zsh-completion
    zsh-syntax-highlighting
    zsh-autosuggestions
    zsh-vi-mode
    web-search
)

source $ZSH/oh-my-zsh.sh
################################################################################

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

check_x11_wayland() {
    if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
        debug "Using Wayland."
        # reference: https://unix.stackexchange.com/a/359244/523957
        __xhost_command="xhost +SI:localuser:$(id -un) >/dev/null 2>&1"
        warning "Executes '$__xhost_command'"
        eval "$__xhost_command"
    fi
}

command_with_email_notification() {
    if [ $# -lt 1 ] || [ $# -gt 3 ]; then
        echo "Usage: command_with_email_notification <command> [directory] [email]"
        echo "Executes the given command in the specified directory (defaults to current directory)"
        echo "and sends an email notification with the status and duration."
        echo "If email is not provided, it will be read from the Git global user configuration."
        return 1
    fi

    local cmd="$1"
    local directory="${2:-.}"
    local email="${3:-$(git config --global user.email)}"

    if [ -z "$email" ]; then
        echo "Email not provided and not found in Git global user configuration."
        return 1
    fi

    local original_dir=$(pwd)
    cd "$directory" || { echo "Failed to change to directory: $directory"; return 1; }

    local start_time=$(date +%s)
    eval "$cmd"
    local exit_status=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    local cmd_status="Success"
    [ $exit_status -ne 0 ] && cmd_status="Failure"

    local subject="Command Execution Notification"
    local body="
<html>
    <head>
        <style>
            body {
                font-family: Arial, sans-serif;
                font-size: 12px;
            }
            .label {
                font-weight: bold;
            }
        </style>
    </head>
    <body>
    <p><span class="label">Status:</span> $cmd_status</p>
    <p><span class="label">Command:</span> $cmd</p>
    <p><span class="label">Duration:</span> $duration seconds</p>
    <p><span class="label">Directory:</span> $(pwd)</p>
    <p><span class="label">Exit Status:</span> $exit_status</p>
    </body>
</html>
"

    echo "Subject: $subject" > email.txt
    echo "Content-Type: text/html; charset=UTF-8" >> email.txt
    echo "MIME-Version: 1.0" >> email.txt
    echo "" >> email.txt
    echo "$body" >> email.txt

    msmtp -a default "$email" < email.txt
    rm email.txt

    cd "$original_dir" || { echo "Failed to restore original directory: $original_dir"; return 1; }
}

webp2png() {
    if has dwebp; then
        dwebp -i $1.webp -o $1.png
    else
        error "dwebp not found."
    fi
}

webm2mp4() {
    if has ffmpeg; then
        ffmpeg -fflags +genpts -i $1.webm -r ${2:-24} $1.mp4
    else
        error "ffmpeg not found."
    fi
}

gif2mp4() {
    if has ffmpeg; then
        ffmpeg -i $1.gif -movflags faststart -pix_fmt yuv420p -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" $1.mp4
    else
        error "ffmpeg not found."
    fi
}

mp42png() {
    if has ffmpeg; then
        ffmpeg -i $1.mp4 -vframes 1 $1.png
    else
        error "ffmpeg not found."
    fi
}

compress_pdf() {
    # ref: https://askubuntu.com/a/256449
    if [[ ! "$#" -eq 2 ]]; then
        error "Usage: compress_pdf INPUT_FILE OUTPUT_FILE"
    elif has gs; then
        gs -sDEVICE=pdfwrite \
            -dCompatibilityLevel=1.4 \
            -dNOPAUSE \
            -dQUIET \
            -dBATCH \
            -dPDFSETTINGS=/printer \
            -sOutputFile=$2 \
            $1
    fi
}

# https://labbots.github.io/google-drive-upload/
[ -f "${HOME}/.google-drive-upload/bin/gupload" ] && [ -x "${HOME}/.google-drive-upload/bin" ] && PATH="${HOME}/.google-drive-upload/bin:${PATH}"

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

${INDENT}webp2png <FILENAME_WITHOUT_EXTENSION>
${INDENT}webm2mp4 <FILENAME_WITHOUT_EXTENSION>
${INDENT}gif2mp4 <FILENAME_WITHOUT_EXTENSION>
${INDENT}mp42png <FILENAME_WITHOUT_EXTENSION>
"
}

start_up() {
    # help;
    # auto_tmux
     
    # hardware_overview;
    # software_overview
     
    check_git_config
    check_x11_wayland

    check_private_ip;
    check_public_ip;

    # set_proxy 
    # unset_proxy
     
    # set_ros
    set_ros2

    echo "Type \"help\" to display supported handy commands."
    zshrc_end_time=$(date +%s%N)
    zshrc_duration=$(( (zshrc_end_time - zshrc_start_time) / 1000000 ))
    debug "$zshrc_duration ms$RESET to start up zsh."
}
start_up
