zshrc_start_time=$(date +%s%N)

# load modules and slurm
# [ -f "/etc/profile.d/modules.sh" ] && source "/etc/profile.d/modules.sh" && module load slurm

export ZSH="$HOME/.oh-my-zsh"
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
export XDG_DATA_DIRS=${XDG_DATA_DIRS:-"/usr/local/share/:/usr/share"}
export XDG_CONFIG_DIRS=${XDG_CONFIG_DIRS:-"/etc/xdg"}
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-"/run/user/$(id -u)"}
# non-standard variable
export XDG_PREFIX_HOME="${HOME}/.local"
display_xdg_envs() {
    echo "XDG_DATA_HOME=$XDG_DATA_HOME"
    echo "XDG_CONFIG_HOME=$XDG_CONFIG_HOME"
    echo "XDG_STATE_HOME=$XDG_STATE_HOME"
    echo "XDG_CACHE_HOME=$XDG_CACHE_HOME"
    echo "XDG_DATA_DIRS=$XDG_DATA_DIRS"
    echo "XDG_CONFIG_DIRS=$XDG_CONFIG_DIRS"
    echo "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
    echo "XDG_PREFIX_HOME=$XDG_PREFIX_HOME"
}

# ref: https://unix.stackexchange.com/a/269085/523957
RESET=$(tput sgr0)
BOLD=$(tput bold)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
PURPLE=$(tput setaf 5)
CYAN=$(tput setaf 6)

error() {
    printf "${RED}${BOLD}ERROR:${RESET} %s\n" "$1"
}
info() {
    printf "${GREEN}${BOLD}INFO:${RESET} %s\n" "$1"
}
warning() {
    printf "${YELLOW}${BOLD}WARNING:${RESET} %s\n" "$1"
}

prepend_to_env_var() {
    if [[ -z "$1" || -z "$2" ]]; then
        error "at least 2 arguments are required.
      For example:
          $0 PATH "$HOME/.local/bin" "/usr/local/bin"
        "
        return 1;
    fi

    local env_var_name="$1"
    shift
    local args=("${@}")

    if [[ -z "${(P)env_var_name}" ]]; then
        export ${env_var_name}=""
    fi

    for (( i = $#args; i > 0; i-- )); do
        dir=${args[i]}
        if [[ -d "$dir" && ! :${(P)env_var_name}: =~ :$dir: ]]; then
            if [[ -z "${(P)env_var_name}" ]]; then
                eval "export ${env_var_name}=\"$dir\""
            else
                eval "export ${env_var_name}=\"$dir:\${${env_var_name}}\""
            fi
        fi
    done
}

append_to_env_var() {
    if [[ -z "$1" || -z "$2" ]]; then
        error "at least 2 arguments are required.
      For example:
          $0 PATH "$HOME/.local/bin" "/usr/local/bin"
        "
        return 1;
    fi

    local env_var_name="$1"
    shift
    local args=("${@}")

    if [[ -z "${(P)env_var_name}" ]]; then
        export ${env_var_name}=""
    fi

    for dir in "${args[@]}"; do
        if [[ -d "$dir" && ! :${(P)env_var_name}: =~ :$dir: ]]; then
            if [[ -z "${(P)env_var_name}" ]]; then
                eval "export ${env_var_name}=\"$dir\""
            else
                eval "export ${env_var_name}=\"\${${env_var_name}}:$dir\""
            fi
        fi
    done
}

remove_from_env_var() {
    if [[ -z "$1" || -z "$2" ]]; then
        error "2 arguments are required.
      For example:
          $0 PATH "$HOME/.local/bin"
        "
        return 1;
    fi
    local env_var_name="$1"
    local path_to_remove="$2"
    local current_value="${(P)env_var_name}"

    current_value="${current_value//:$path_to_remove:/:}"
    current_value="${current_value//:$path_to_remove/}"
    current_value="${current_value//$path_to_remove:/}"

    eval "export ${env_var_name}=\"${current_value}\""
}

prepend_to_env_var PATH "$HOME/.local/bin" "/usr/local/bin"
prepend_to_env_var LD_LIBRARY_PATH "$HOME/.local/lib" "/usr/local/lib"
prepend_to_env_var MANPATH "$HOME/.local/man" "/usr/local/man"

check_public_ip() {
    exec 2>/dev/null
    local ipinfo=$(curl ipinfo.io)
    echo "${PURPLE}Public Networking: ${RESET}"
    echo $ipinfo | grep --color=never "\"city\":"
    echo $ipinfo | grep --color=never "\"ip\":"
    exec 2>&1
}
check_proxy_status() {
    check_public_ip
    echo "${YELLOW}VPN Client Status: ${RESET}"
    if [[ $(uname -r | grep 'WSL2') ]]; then
        warning "Unknown. For WSL2, the VPN client is probably running on the host machine. Please check manually.";
    elif [ -f /.dockerenv ]; then
        warning "Unknown. For a Docker container, the VPN client is probably running on the host machine. Please check manually.";
    else
        echo "  $(systemctl is-active sing-box.service)"
    fi
    echo -e "${CYAN}Related Environment Variables: ${RESET}"
    local proxy_env=$(env | grep --color=never -i 'proxy')
    echo $proxy_env | while read line; do echo "  ${line}"; done
}

set_proxy() {
    if [[ $(uname -r | grep 'WSL2') ]]; then
        warning "Make sure the VPN client is working on host."
        local host="'$(cat /etc/resolv.conf | grep '^nameserver' | cut -d ' ' -f 2)'"
        local port=1080
    elif [ -f /.dockerenv ]; then
        warning "Only \"host\" networking mode is supported."
        local host="'127.0.0.1'"
        local port=1080
    else
        if [[ $(lsb_release -d | grep 'Ubuntu') ]]; then
            local host="'127.0.0.1'"
            local port=1080
            info "Start the VPN client service."
            sudo systemctl start sing-box.service
            info "Set GNOME networking proxy settings."
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
            error "Unsupported for this platform."
        fi
    fi
    info "Set environment variables and configure for specific programs."
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
    git config --global http.proxy ${http_proxy}
    git config --global https.proxy ${https_proxy}

    info "Wait 5 seconds before checking current public IP."
    sleep 5s;
    check_public_ip
}

unset_proxy() {
    if [[ $(uname -r | grep 'WSL2') || -f /.dockerenv ]]; then
        ;
    else
        if [[ $(lsb_release -d | grep 'Ubuntu') ]]; then
            info "Stop VPN client service."
            sudo systemctl stop sing-box.service
            info "Unset GNOME networking proxy settings."
            dconf write /system/proxy/mode "'none'"
        else
            error "Unsupported for this platform."
        fi
    fi
    info "Unset environment variables and unconfigure for specific programs."
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
    git config --global --unset http.proxy
    git config --global --unset https.proxy
    info "Wait 2 seconds before checking current public IP."
    sleep 2s;
    check_public_ip
}

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
# ZSH_THEME="robbyrussell"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
HIST_STAMPS="yyyy-mm-dd"

# Would you like to use another custom folder than $ZSH/custom?
ZSH_CUSTOM=${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}
# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.

ensure_install_plugins() {
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
}
ensure_install_plugins

source "${XDG_CONFIG_HOME}/zsh/catppuccin_latte-zsh-syntax-highlighting.zsh"
source "${ZSH_CUSTOM}/plugins/zsh-autoenv/autoenv.zsh"
plugins=(
    git
    docker
    docker-compose
    # The following are manually installed plugins
    conda-zsh-completion
    zsh-syntax-highlighting
    zsh-autosuggestions
)

source $ZSH/oh-my-zsh.sh

# Preferred editor
if (( $+commands[nvim] )); then
    export SUDO_EDITOR='nvim'
    export EDITOR='nvim'
elif (( $+commands[vim] )); then
    export SUDO_EDITOR='vim'
    export EDITOR='vim'
elif (( $+commands[vi] )); then
    export SUDO_EDITOR='vi'
    export EDITOR='vi'
fi

# Compilation
export ARCHFLAGS="-arch $(uname -m)"
export NUMCPUS=`grep -c '^processor' /proc/cpuinfo`
alias pmake='time nice make -j${NUMCPUS} --load-average=${NUMCPUS}'

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
alias python="python3"
alias lg="lazygit"
alias zshconfig="${EDITOR} ${HOME}/.zshrc"
alias ohmyzsh="${EDITOR} ${HOME}/.oh-my-zsh"
alias nvimconfig="${EDITOR} ${XDG_CONFIG_HOME}/nvim"
alias tmuxconfig="${EDITOR} ${XDG_CONFIG_HOME}/tmux"

export NVM_DIR="${XDG_CONFIG_HOME}/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm

eval "$(starship init zsh)"

# <<< personal micromamba initialization <<<
export MAMBA_EXE="${XDG_PREFIX_HOME}/bin/micromamba";
export MAMBA_ROOT_PREFIX="${XDG_DATA_HOME}/micromamba";
__mamba_setup="$("$MAMBA_EXE" shell hook --shell zsh --root-prefix "$MAMBA_ROOT_PREFIX" 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__mamba_setup"
else
    alias micromamba="$MAMBA_EXE"  # Fallback on help from mamba activate
fi
unset __mamba_setup
# <<< personal micromamba initialization <<<

display_software_versions_helper() {
    local cli_program
    if [ alias "$cli_program" >/dev/null 2>&1 ]; then
        cli_program=$(alias "$1" | cut -d = -f 2)
    else
        cli_program="$1"
    fi
    local command_to_print_version="$2"
    if command -v "$cli_program" >/dev/null 2&>1; then
        # echo -e -n "${GREEN}${cli_program}${RESET}${delimeter}v"
        printf "${GREEN}%-16s %s" "${cli_program}" "v"
        eval "$command_to_print_version"
        printf "${RESET}"
    else
        local RED=$(tput setaf 1)
        local BOLD=$(tput bold)
        local RESET=$(tput sgr0)
        printf "${RED}%-16s %s\n${RESET}" "${cli_program}" "not found"
    fi
}

display_software_versions() {
    exec 2>/dev/null
    display_software_versions_helper "ldd" "ldd --version | head -n 1 | awk '{ print \$5; }'"
    display_software_versions_helper "gcc" "gcc --version | head -n 1 | awk '{ print \$4; }'"
    display_software_versions_helper "nvcc" "nvcc --version | sed -n '4p' | awk '{ print \$5; }' | sed 's/.\$//'"
    echo
    display_software_versions_helper "zsh" "zsh --version | awk '{ print \$2; }'"
    display_software_versions_helper "tmux" "tmux -V | awk '{ print \$2; }'"
    display_software_versions_helper "nvim" "nvim --version | head -n 1 | awk '{ print \$2; }' | cut -dv -f2"
    display_software_versions_helper "vim" "vim --version | head -n 1 | awk '{ print \$5;}'"
    display_software_versions_helper "git" "git --version | awk '{ print \$3; }'"
    display_software_versions_helper "cmake" "cmake --version | head -n 1 | awk '{ print \$3; }'"
    if [[ ! $(uname -r | grep 'WSL2') && ! -f /.dockerenv ]]; then
        display_software_versions_helper "docker" "docker --version | awk '{print \$3}' | cut -d, -f1"
    fi
    echo
    display_software_versions_helper "python" "python --version | awk '{ print \$2; }'"
    display_software_versions_helper "conda" "conda --version | awk '{ print \$2; }'"
    display_software_versions_helper "mamba" "mamba --version"
    display_software_versions_helper "micromamba" "micromamba --version"
    echo
    if [[ $(lsb_release -d | grep 'Ubuntu') ]]; then
        display_software_versions_helper "gnome-shell" "gnome-shell --version | awk '{ print \$3; }'"
        echo
        if [ -z "${ROS_DISTRO}" ]; then
            printf "${RED}%-16s %s${RESET}\n" "ROS" "not found"
        else
            printf "${GREEN}%-16s %s${RESET}\n" "ROS" "${ROS_DISTRO}"
        fi
        echo
    fi
    exec 2>&1
}

system_overview() {
    if [ -f /.dockerenv ]; then
        echo "${RED}A Docker container.${RESET}";
    fi
    echo
    echo "${YELLOW}$(whoami)${RESET} @ ${YELLOW}$(hostname)${RESET} @ ${YELLOW}$(hostname -I | awk '{ print $1; }')${RESET}"
    echo
    check_public_ip
    echo
    echo "${CYAN}OS Kernel:${RESET}\t\t$(uname -sr)"
    echo "${CYAN}OS Distro:${RESET}\t\t$(cat /etc/os-release | grep ^'PRETTY_NAME' | grep -oP '"\K[^"]+(?=")')"
    echo "${CYAN}CPU Device:${RESET}\t\t$(cat /proc/cpuinfo | grep ^'model name' | sed -n '1p' | grep -oP '(?<=: ).*')"
    echo "${CYAN}CPU Processing Units:${RESET}\t$(nproc --all)"
    # echo "CPU Usage: $((100-$(vmstat 1 2 | tail -1 | awk '{print $15}')))%"
    if [ -f "/proc/driver/nvidia/version" ]; then
        if [ ! -x "$(command -v nvidia-smi)" ]; then
            error "command \"nvidia-smi\" not found."
        else
            echo "${CYAN}NVIDIA GPU Device:${RESET}\t$(nvidia-smi -L | sed 's/([^)]*)//g')"
        fi
        echo "${CYAN}NVIDIA Driver Version:${RESET}\t$(grep -oP 'NVRM version:\s+NVIDIA UNIX\s+\S+\s+Kernel Module\s+\K[0-9.]+' /proc/driver/nvidia/version)"
    else
        error "NVIDIA Driver not found."
    fi
    echo "${CYAN}Available Memory:${RESET}\t$(free -mh | grep ^Mem | awk '{ print $7; }')/$(free -mh | grep ^Mem | awk '{ print $2; }')"
    if [ -f /.dockerenv ]; then
        echo "${CYAN}Available Storage:${RESET}\t$(df -h --total | grep --color=never '/etc/hosts' | awk '{ print $4}')/$(df -h --total | grep --color=never '/etc/hosts' | awk '{ print $2}')"
    else
        echo "${CYAN}Available Storage:${RESET}\t$(df -h --total | grep --color=never 'total' | awk '{ print $4}')/$(df -h --total | grep --color=never 'total' | awk '{ print $2}')"
    fi
}
# system_overview

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

quick_open_docker_container() {
    if command -v "docker" >/dev/null 2&>1; then
        ;
    else
        error "docker: command not found.";
        return 1;
    fi
    docker exec -it $1 zsh
}

alias latex='quick_open_docker_container latex'
alias ros='quick_open_docker_container ros'

zshrc_end_time=$(date +%s%N)
zshrc_duration=$(( (zshrc_end_time - zshrc_start_time) / 1000000 ))

greeting(){
    echo "${GREEN}Avaiable Commands:${RESET}
  greeting, system_overview
  display_software_versions, display_xdg_envs, display_typefaces
  [un]set_proxy, check_public_ip, check_proxy_status
  [pre|ap]pend_to_env_var, remove_from_env_var";
    check_public_ip;
    if [[ -n ${ROS_DISTRO} && -f "/opt/ros/${ROS_DISTRO}/setup.zsh" ]]; then
        source "/opt/ros/${ROS_DISTRO}/setup.zsh";
        info "Using ROS $BOLD$ROS_DISTRO$RESET.";
    fi
    info "$CYAN$zshrc_duration ms$RESET to start up."
}
greeting
