#!/usr/bin/env zsh
zshrc_start_time=$(date +%s%N)

source ~/.sh_utils/basics.sh
source ~/.sh_utils/helpers.sh
source ~/.sh_utils/checkers.sh
source ~/.sh_utils/network_management.sh
source ~/.sh_utils/tools.sh

export USER=$USERNAME

export LANG=${LANG:-"en_US.UTF-8"}
export LC_ALL=${LC_ALL:-"en_US.UTF-8"}
export LC_CTYPE=${LC_CTYPE:-"en_US.UTF-8"}

# XDG Base Directory Specification, 
# Ref: https://specifications.freedesktop.org/basedir-spec/latest/
export XDG_DATA_HOME=${XDG_DATA_HOME:-"$HOME/.local/share"}
export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-"$HOME/.config"}
export XDG_STATE_HOME=${XDG_STATE_HOME:-"$HOME/.local/state"}
export XDG_CACHE_HOME=${XDG_CACHE_HOME:-"$HOME/.cache"}
export XDG_DATA_DIRS=${XDG_DATA_DIRS:-"/usr/local/share:/usr/share"}
export XDG_CONFIG_DIRS=${XDG_CONFIG_DIRS:-"/etc/xdg"}
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-"/run/user/$(id -u)"}
# Non-standard XDG variables
export XDG_PREFIX_HOME="${HOME}/.local"
export XDG_PREFIX_DIR="/usr/local"
# Add XDG vars into envs
prepend_env PATH "${XDG_PREFIX_HOME}/bin" "${XDG_PREFIX_DIR}/bin"
prepend_env LD_LIBRARY_PATH "${XDG_PREFIX_HOME}/lib" "${XDG_PREFIX_DIR}/lib"
prepend_env MANPATH "${XDG_PREFIX_HOME}/man" "${XDG_PREFIX_DIR}/man"

################################################################################
# Condas:
# micromamba is preferred rather than miniconda
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

# Preferred editors:
if has "nvim"; then
    export SUDO_EDITOR='nvim'
    export EDITOR='nvim'
    if has "git"; then
        git config --global core.editor "nvim"
    fi
elif has "vim"; then
    export SUDO_EDITOR='vim'
    export EDITOR='vim'
    if has "git"; then
        git config --global core.editor "vim"
    fi
elif has "vi"; then
    export SUDO_EDITOR='vi'
    export EDITOR='vi'
    if has "git"; then
        git config --global core.editor "vi"
    fi
fi

# Aliases:
alias ohmyzsh="${EDITOR} ${HOME}/.oh-my-zsh"
alias zshconfig="${EDITOR} ${HOME}/.zshrc"
alias nvimconfig="${EDITOR} ${XDG_CONFIG_HOME}/nvim"
alias tmuxconfig="${EDITOR} ${XDG_CONFIG_HOME}/tmux"
alias sshconfig="${EDITOR} ${HOME}/.ssh/config"
alias starshipconfig="${EDITOR} ${XDG_CONFIG_HOME}/starship.toml"
alias alacrittyconfig="${EDITOR} $XDG_CONFIG_HOME/alacritty/alacritty.toml"
alias kittyconfig="${EDITOR} $XDG_CONFIG_HOME/kitty/kitty.conf"

alias e='$EDITOR'
alias v='$EDITOR'
alias s='web_search google'

alias python="python3"
alias lg="lazygit"
alias t="tmux"
alias ta="tmux a"

export ARCHFLAGS="-arch $(uname -m)"
export NUMCPUS=$(grep -c '^processor' /proc/cpuinfo)
alias pmake='time nice make -j${NUMCPUS} --load-average=${NUMCPUS}'
alias latex='enter_docker_container latex'
robotics(){
    if [[ -z "$1" ]]; then
        enter_docker_container robotics
    else 
        enter_docker_container robotics-"$1"
    fi
}

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

download_zsh_plugins() {
    if [[ ! -d "${ZSH_CUSTOM}/plugins/conda-zsh-completion" ]]; then
        info "Installing the latest conda-zsh-completion"
        git clone --depth 1 https://github.com/conda-incubator/conda-zsh-completion "${ZSH_CUSTOM}/plugins/conda-zsh-completion"
    fi
    if [[ ! -d "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting" ]]; then
        info "Installing the latest zsh-syntax-highlighting"
        git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting"
    fi
    if [[ ! -d "${ZSH_CUSTOM}/plugins/zsh-autosuggestions" ]]; then
        info "Installing the latest zsh-autosuggestions"
        git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions.git "${ZSH_CUSTOM}/plugins/zsh-autosuggestions"
    fi
    if [[ ! -d "${ZSH_CUSTOM}/plugins/zsh-autoenv" ]]; then
        info "Installing the latest zsh-autoenv"
        git clone --depth 1 https://github.com/Tarrasch/zsh-autoenv "${ZSH_CUSTOM}/plugins/zsh-autoenv"
    fi
    if [[ ! -d "${ZSH_CUSTOM}/plugins/zsh-vi-mode" ]]; then
        info "Installing the latest zsh-vi-mode"
        git clone --depth 1 https://github.com/jeffreytse/zsh-vi-mode "${ZSH_CUSTOM}/plugins/zsh-vi-mode"
    fi
    if [[ ! -d "${XDG_DATA_HOME}/tmux/plugins/catppuccin/tmux" ]]; then
        info "Installing the latest catppuccin/tmux"
        git clone --depth 1 https://github.com/catppuccin/tmux.git ${XDG_DATA_HOME}/tmux/plugins/catppuccin/tmux
    fi
}

setup_nvm() {
    export NVM_DIR="${XDG_CONFIG_HOME}/nvm"
    if [[ ! -d "$NVM_DIR" ]]; then
        info "Installing the latest nvm"
        mkdir -p ${NVM_DIR} && \
        (unset ZSH_VERSION && PROFILE=/dev/null bash -c 'wget -qO- "https://github.com/nvm-sh/nvm/raw/master/install.sh" | bash') && \
        # Load nvm and install the latest lts nodejs
        . "${NVM_DIR}/nvm.sh" && nvm install --lts node && \
        # Install tree-sitter-cli
        npm install -g tree-sitter-cli
    fi 
    # Load nvm
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
}

setup_starship() {
    if [[ ! -x "${XDG_PREFIX_HOME}/bin/starship" ]]; then
        info "Installing the latest starship."
        (unset ZSH_VERSION && wget -qO- https://starship.rs/install.sh | /bin/sh -s -- --yes -b ${XDG_PREFIX_HOME}/bin 1>/dev/null 2>&1)
    fi
    # Load starship
    eval "$(starship init zsh)"
}

setup_google_drive_upload() {
    # https://labbots.github.io/google-drive-upload/
    if [[ ! -d "${HOME}/.google-drive-upload" ]]; then
        info "Installing the latest google-drive-upload."
        # Store output in temp file
        tmpfile=$(mktemp)
        if ! curl --compressed -Ls https://github.com/labbots/google-drive-upload/raw/master/install.sh | sh -s > "$tmpfile" 2>&1; then
            # If failed, show output
            error "Failed to install: $(cat "$tmpfile")"
            rm "$tmpfile"
            return 1
        fi
        # On success, discard output
        rm "$tmpfile"
    fi
    prepend_env PATH "${HOME}/.google-drive-upload/bin"
}

setup_lazygit() {
    if [[ ! -x "$XDG_PREFIX_HOME/bin/lazygit" ]]; then
        info "Installing the latest lazygit"
        LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*') && \
        curl -s -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" && \
        tar xf lazygit.tar.gz lazygit && \
        install -Dm 755 lazygit ${XDG_PREFIX_HOME}/bin && \
        rm lazygit.tar.gz lazygit
    fi
}

setup_yazi() {
    if [[ ! -x "$XDG_PREFIX_HOME/bin/yazi" ]]; then
        info "Installing the latest yazi (linux, x86_64, gnu)"
        curl -s "https://api.github.com/repos/sxyazi/yazi/releases/latest" | \
            grep 'browser_download_url.*yazi-x86_64-unknown-linux-gnu.zip' | \
            cut -d : -f 2,3 | \
            tr -d \" | \
            wget -qi -
        unzip -qq yazi-x86_64-unknown-linux-gnu.zip 
        cp yazi-x86_64-unknown-linux-gnu/ya* $XDG_PREFIX_HOME/bin/ 
        rm -r yazi-x86_64-unknown-linux-gnu*
    fi
    if has "yazi"; then
        function y() {
            local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
            yazi "$@" --cwd-file="$tmp"
            if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
                builtin cd -- "$cwd"
            fi
            rm -f -- "$tmp"
        }
    fi
}

setup_fzf() {
    if [[ ! -d "$HOME/.fzf" ]]; then
        info "Cloning the latest fzf"
        git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
        info "Installing the latest fzf"
        ~/.fzf/install --key-bindings --completion --no-update-rc 1>/dev/null 2>&1
    fi 
    [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
    export FZF_CTRL_R_OPTS="
--bind 'ctrl-y:execute-silent(echo -n {2..} | xclipboard -selection clipboard)+abort'
--color header:italic
--header 'Press CTRL-Y to copy command into clipboard'"
    # Print tree structure in the preview window
    export FZF_ALT_C_OPTS="--walker-skip .git,node_modules,target --preview 'tree -C {}'"
}

setup_luarocks() {
    LUAROCKS_VERSION=3.11.1
    if [[ ! -x "$XDG_PREFIX_HOME/bin/luarocks" ]] || \
       [[ "$($XDG_PREFIX_HOME/bin/luarocks --version | head -n 1 | cut -d ' ' -f 2)" != "$LUAROCKS_VERSION" ]]; then
        info "Installing the luarocks ${LUAROCKS_VERSION}".
        wget -q https://luarocks.github.io/luarocks/releases/luarocks-${LUAROCKS_VERSION}-linux-x86_64.zip
        unzip -qq luarocks-${LUAROCKS_VERSION}-linux-x86_64.zip 
        cp luarocks-${LUAROCKS_VERSION}-linux-x86_64/luarocks* ${XDG_PREFIX_HOME}/bin && \
        rm -r luarocks-${LUAROCKS_VERSION}-linux-x86_64*
    fi
}

setup_tpm() {
    if [[ ! -d "${XDG_PREFIX_HOME}/share/tmux/plugins/tpm" ]]; then
        info "Installing the latest tpm."
        git clone --depth 1 https://github.com/tmux-plugins/tpm ${XDG_PREFIX_HOME}/share/tmux/plugins/tpm
    fi 
}

setup_kitty() {
    if [[ -x "${XDG_PREFIX_HOME}/bin/kitty" ]]; then
        if has gsettings; then
            if gsettings set org.gnome.desktop.default-applications.terminal exec "${XDG_PREFIX_HOME}/bin/kitty" 2>/dev/null; then
                debug "Set kitty as default terminal"
            else
                error "Failed to set kitty as default terminal"
            fi
        else
            warning "gsettings not found - cannot set kitty as default terminal"
        fi
    else
        error "kitty not found at ${XDG_PREFIX_HOME}/bin/kitty"
    fi
}

# Rust
if [[ -f "$HOME/.cargo/env" ]]; then
    . "$HOME/.cargo/env"
fi

download_zsh_plugins
setup_starship
setup_google_drive_upload
setup_nvm
setup_tpm
setup_lazygit
setup_yazi
setup_fzf
setup_luarocks
setup_kitty

source "${XDG_CONFIG_HOME}/zsh/catppuccin_latte-zsh-syntax-highlighting.zsh"
source "${ZSH_CUSTOM}/plugins/zsh-autoenv/autoenv.zsh"

# Configure zsh-vi-mode
# ref: https://github.com/jeffreytse/zsh-vi-mode?tab=readme-ov-file#configuration-function
zvm_config() {
    ZVM_VI_INSERT_ESCAPE_BINDKEY=jk
    # Solve the conflicts with fzf
    # https://github.com/jeffreytse/zsh-vi-mode?tab=readme-ov-file#execute-extra-commands
    zvm_after_init_commands+=('[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh')
}

source "$ZSH_CUSTOM/plugins/zsh-vi-mode/zsh-vi-mode.zsh"

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

# Add a newline
precmd() {
    echo
}

check_git_config
check_x11_wayland

set_ros2

safely_source "${HOME}/.secrets/llm_api_keys.sh"

# echo "Type \"help\" to display supported handy commands."
zshrc_end_time=$(date +%s%N)
zshrc_duration=$(( (zshrc_end_time - zshrc_start_time) / 1000000 ))
info "$zshrc_duration ms$RESET to start up zsh."
