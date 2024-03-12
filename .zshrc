# zshrc_start_time=$(date +%s%N)

[ -f "/etc/profile.d/modules.sh" ] && source "/etc/profile.d/modules.sh" && module load slurm

export LANG=${LANG:-"en_US.UTF-8"}
export LC_ALL=${LC_ALL:-"en_US.UTF-8"}
export LC_CTYPE=${LC_CTYPE:-"en_US.UTF-8"}

export XDG_DATA_HOME=${XDG_DATA_HOME:-"$HOME/.local/share"}
export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-"$HOME/.config"}
export XDG_STATE_HOME=${XDG_STATE_HOME:-"$HOME/.local/state"}
export XDG_CACHE_HOME=${XDG_CACHE_HOME:-"$HOME/.cache"}
export XDG_DATA_DIRS=${XDG_DATA_DIRS:-"/usr/local/share/:/usr/share"}
export XDG_CONFIG_DIRS=${XDG_CONFIG_DIRS:-"/etc/xdg"}
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-"/run/user/$(id -u)"}
# non-standard variable
export XDG_PREFIX_HOME="${HOME}/.local"

export ZSH="$HOME/.oh-my-zsh"
export USER=$USERNAME

prepend_to_env_var() {
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

prepend_to_env_var PATH "$HOME/.local/bin" "/usr/local/bin"
prepend_to_env_var LD_LIBRARY_PATH "$HOME/.local/lib" "/usr/local/lib"
prepend_to_env_var MANPATH "$HOME/.local/man" "/usr/local/man"

alias python="python3"
alias lg="lazygit"

if [[ $(uname -r | grep 'WSL2') ]]; then 
    local host_ip=$(cat /etc/resolv.conf | grep '^nameserver' | cut -d ' ' -f 2)
    export http_proxy=${http_proxy:-"${host_ip}:1080"}
    export https_proxy=${https_proxy:-"${host_ip}:1080"}
else 
    export http_proxy=${http_proxy:-"http://127.0.0.1:1080"}
    export https_proxy=${https_proxy:-"http://127.0.0.1:1080"}
fi
export no_proxy=${no_proxy:-"localhost,.hkust-gz.edu.cn"}

export HTTP_PROXY=${HTTP_PROXY:-${http_proxy}}
export HTTPS_PROXY=${HTTPS_PROXY:-${https_proxy}}
export NO_PROXY=${NO_PROXY:-${no_proxy}}

broadcast_proxies() {
    if [[ -z "${http_proxy}" ]]; then
        git config --global --unset http.proxy
    else
        git config --global http.proxy ${http_proxy}
    fi
    if [[ -z "${https_proxy}" ]]; then
        git config --global --unset https.proxy
    else
        git config --global https.proxy ${https_proxy}
    fi
}
broadcast_proxies

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
alias zshconfig="${EDITOR} ${HOME}/.zshrc"
alias ohmyzsh="${EDITOR} ${HOME}/.oh-my-zsh"
alias nvimconfig="${EDITOR} ${XDG_CONFIG_HOME}/nvim"
alias tmuxconfig="${EDITOR} ${XDG_CONFIG_HOME}/tmux"

export NVM_DIR="${XDG_CONFIG_HOME}/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm

eval "$(starship init zsh)"

# <<< personal conda initialization, not need to `conda init zsh` <<<
# I personally download miniconda3 to "${XDG_PREFIX_HOME}/miniconda3"
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
# <<< personal conda initialization <<<
 
gpu_driver_path="/usr/lib/modules/$(uname -r)/kernel/drivers/video/nvidia.ko"
print_sys_info() {
    echo
    echo "$(whoami) @ $(hostname) @ $(hostname -I | awk '{ print $1; }')"
    echo
    echo "OS: $(uname -sr)"
    echo "Distro: $(cat /etc/os-release | grep ^'PRETTY_NAME' | grep -oP '"\K[^"]+(?=")')"
    echo "CPU Device: $(cat /proc/cpuinfo | grep ^'model name' | sed -n '1p' | grep -oP '(?<=: ).*')"
    echo "CPU Usage: $((100-$(vmstat 1 2 | tail -1 | awk '{print $15}')))%"
    if [ ! -f ${gpu_driver_path} ]; then
        echo "NVIDIA GPU Driver not found."
    else
        echo "NVIDIA GPU Driver Version $(modinfo ${gpu_driver_path} | grep ^version | grep -oP '(?<=:        ).*')"
        if [ ! -x "$(command -v nvidia-smi)" ]; then
            echo "command nvidia-smi not found."
        else
            echo "GPU Device: $(nvidia-smi -L | sed 's/([^)]*)//g')"
        fi
    fi
    echo "Avaiable Memory: $(free -mh | grep ^Mem | awk '{ print $7; }') / $(free -mh | grep ^Mem | awk '{ print $2; }')"
    echo
}
# print_sys_info


check_version() {
    local cli="${1}"
    local command_to_print_version="${2}"
    if command -v "$cli" &>/dev/null; then
        eval "$command_to_print_version"
    else
        echo "$cli not found" >&2
    fi
}

check_version_all() {
    check_version "zsh" "echo -e \"zsh\tv$(zsh --version | awk '{ print $2; }')\""
    check_version "tmux" "echo -e \"tmux\tv$(tmux -V | awk '{ print $2; }')\""
    check_version "nvim" "echo -e \"nvim\t$(nvim --version | sed -n '1p' | head -n 1 | awk '{ print $2; }')\""
    check_version "python" "echo -e \"python\tv$(python --version | awk '{ print $2; }')\""
    check_version "git" "echo -e \"git\tv$(git --version | awk '{ print $3; }')\""
    if [[ ! $(uname -r | grep 'WSL2') ]]; then 
        check_version "docker" "echo -e \"docker\tv$(docker --version | awk '{ print $3; }' | sed 's/.$//')\""
    fi
    if [ -f ${gpu_driver_path} ]; then
        check_version "nvcc " "echo -e \"nvcc\tv$(nvcc --version | sed -n '4p' | awk '{ print $5; }' | sed 's/.$//')\""
    fi
    check_version "conda" "echo -e \"conda\tv$(conda --version | awk '{ print $2; }')\""
    echo
}

# zshrc_end_time=$(date +%s%N)
# zshrc_duration=$(( (zshrc_end_time - zshrc_start_time) / 1000000 ))
# echo "$zshrc_duration ms to execute ${HOME}/.zshrc"
