#!/usr/env/bin bash
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

check_x11_wayland() {
    if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
        debug "Using Wayland."
        # reference: https://unix.stackexchange.com/a/359244/523957
        __xhost_command="xhost +SI:localuser:$(id -un) >/dev/null 2>&1"
        debug "Executes '$__xhost_command'"
        eval "$__xhost_command"
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
