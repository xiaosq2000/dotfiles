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
        git clone --depth 1 https://github.com/conda-incubator/conda-zsh-completion "${ZSH_CUSTOM}/plugins/conda-zsh-completion" 1>/dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            complete "Done"
        else 
            error "Failed"
        fi
    fi
    if [[ ! -d "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting" ]]; then
        info "Installing the latest zsh-syntax-highlighting"
        git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting" 1>/dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            complete "Done"
        else 
            error "Failed"
        fi
    fi
    if [[ ! -d "${ZSH_CUSTOM}/plugins/zsh-autosuggestions" ]]; then
        info "Installing the latest zsh-autosuggestions"
        git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions.git "${ZSH_CUSTOM}/plugins/zsh-autosuggestions" 1>/dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            complete "Done"
        else 
            error "Failed"
        fi
    fi
    if [[ ! -d "${ZSH_CUSTOM}/plugins/zsh-autoenv" ]]; then
        info "Installing the latest zsh-autoenv"
        git clone --depth 1 https://github.com/Tarrasch/zsh-autoenv "${ZSH_CUSTOM}/plugins/zsh-autoenv" 1>/dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            complete "Done"
        else 
            error "Failed"
        fi
    fi
    if [[ ! -d "${ZSH_CUSTOM}/plugins/zsh-vi-mode" ]]; then
        info "Installing the latest zsh-vi-mode"
        git clone --depth 1 https://github.com/jeffreytse/zsh-vi-mode "${ZSH_CUSTOM}/plugins/zsh-vi-mode" 1>/dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            complete "Done"
        else 
            error "Failed"
        fi
    fi
    # if [[ ! -d "${XDG_DATA_HOME}/tmux/plugins/catppuccin/tmux" ]]; then
    #     info "Installing the latest catppuccin/tmux"
    #     git clone --depth 1 https://github.com/catppuccin/tmux.git ${XDG_DATA_HOME}/tmux/plugins/catppuccin/tmux 1>/dev/null 2>&1
    #     if [[ $? -eq 0 ]]; then
    #         complete "Done"
    #     else 
    #         error "Failed"
    #     fi
    # fi
}

setup_nvm() {
    export NVM_DIR="${XDG_CONFIG_HOME}/nvm"
    # Install
    if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
        info "Installing the latest nvm"
        mkdir -p ${NVM_DIR} && \
        (unset ZSH_VERSION && PROFILE=/dev/null bash -c 'wget -qO- "https://github.com/nvm-sh/nvm/raw/master/install.sh" | bash' 1>/dev/null 2>&1) && \

        # Load
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        info "Installing the latest lts node.js"
        nvm install --lts node 1>/dev/null 2>&1

        info "Installing tree-sitter-cli"
        npm install -g tree-sitter-cli 1>/dev/null 2>&1

        if [[ -s "$NVM_DIR/nvm.sh" ]]; then
            \. "$NVM_DIR/nvm.sh"
            completed "nvm version: $(nvm --version)"
            completed "node version: $(node --version)"
        else
            error "Failed to install nvm"
            rm -rf $NVM_DIR
        fi
    fi
    # Load
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
}

setup_starship() {
    # Install
    if [[ ! -x "${XDG_PREFIX_HOME}/bin/starship" ]]; then
        info "Installing the latest starship."
        (unset ZSH_VERSION && wget -qO- https://starship.rs/install.sh | /bin/sh -s -- --yes -b ${XDG_PREFIX_HOME}/bin 1>/dev/null 2>&1)
    fi
    # Load
    eval "$(starship init zsh)"
}

setup_google_drive_upload() {
    # https://labbots.github.io/google-drive-upload/
    if ! has "${HOME}/.google-drive-upload/bin/gupload"; then
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
        if has "${HOME}/.google-drive-upload/bin/gupload"; then
            completed "Version: $(${HOME}/.google-drive-upload/bin/gupload --version | grep '^LATEST_INSTALLED_SHA' | cut -d' ' -f2)"
        else 
            error "Failed to install google-drive-upload"
        fi 
    fi
    # Load
    prepend_env PATH "${HOME}/.google-drive-upload/bin"
}

setup_lazygit() {
    if ! has "$XDG_PREFIX_HOME/bin/lazygit"; then
        info "Installing the latest lazygit"
        LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*') && \
        curl -sS --no-progress-meter -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" && \
        tar xf lazygit.tar.gz lazygit && \
        install -Dm 755 lazygit ${XDG_PREFIX_HOME}/bin && \
        rm lazygit.tar.gz lazygit
        if has "$XDG_PREFIX_HOME/bin/lazygit"; then
            completed "lazygit version: $($XDG_PREFIX_HOME/bin/lazygit --version)"
        else 
            error "Failed to install lazygit"
        fi
    fi
}

setup_lazydocker() {
    if ! has "$XDG_PREFIX_HOME/bin/lazydocker"; then
        info "Installing the latest lazydocker"
        curl -sS --no-progress-meter https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
        if has "$XDG_PREFIX_HOME/bin/lazygit"; then
            completed "lazydocker version: $($XDG_PREFIX_HOME/bin/lazydocker --version | head -n 1 | cut -d' ' -f2)"
        else 
            error "Failed to install lazydocker"
        fi
    fi
}

setup_yazi() {
    # Install
    if ! has "$XDG_PREFIX_HOME/bin/yazi"; then
        info "Installing the latest yazi (linux, x86_64, gnu)"
        curl -s "https://api.github.com/repos/sxyazi/yazi/releases/latest" | \
            grep 'browser_download_url.*yazi-x86_64-unknown-linux-gnu.zip' | \
            cut -d : -f 2,3 | \
            tr -d \" | \
            wget -qi -
        unzip -qq yazi-x86_64-unknown-linux-gnu.zip 
        cp yazi-x86_64-unknown-linux-gnu/ya* $XDG_PREFIX_HOME/bin/ 
        rm -r yazi-x86_64-unknown-linux-gnu*

        if has "$XDG_PREFIX_HOME/bin/yazi"; then
            completed "yazi version: $($XDG_PREFIX_HOME/bin/yazi --version | cut -d' ' -f2)"
        else 
            error "Failed to install yazi"
        fi
    fi
    # Configuration
    if has "$XDG_PREFIX_HOME/bin/yazi"; then
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
    # Install
    if [[ ! -d "$HOME/.fzf" ]]; then
        info "Installing the latest fzf"
        git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf 1>/dev/null 2>&1
        ~/.fzf/install --key-bindings --completion --no-update-rc 1>/dev/null 2>&1
        if has "$XDG_PREFIX_HOME/bin/fzf"; then
            completed "fzf version: $($XDG_PREFIX_HOME/bin/fzf --version | cut -d' ' -f1)"
        else 
            error "Failed to install yazi"
        fi
    fi 
    # Load
    if [[ -f ~/.fzf.zsh ]]; then
        source ~/.fzf.zsh
        export FZF_CTRL_R_OPTS="
--bind 'ctrl-y:execute-silent(echo -n {2..} | xclipboard -selection clipboard)+abort'
--color header:italic
--header 'Press CTRL-Y to copy command into clipboard'"
        # Print tree structure in the preview window
        export FZF_ALT_C_OPTS="--walker-skip .git,node_modules,target --preview 'tree -C {}'"
        # Theme: Rose Pine Main
        export FZF_DEFAULT_OPTS="--color=fg:#908caa,bg:#191724,hl:#ebbcba --color=fg+:#e0def4,bg+:#26233a,hl+:#ebbcba --color=border:#403d52,header:#31748f,gutter:#191724 --color=spinner:#f6c177,info:#9ccfd8 --color=pointer:#c4a7e7,marker:#eb6f92,prompt:#908caa"
        # # Theme: Rose Pine Moon
        # export FZF_DEFAULT_OPTS="--color=fg:#908caa,bg:#232136,hl:#ea9a97 --color=fg+:#e0def4,bg+:#393552,hl+:#ea9a97 --color=border:#44415a,header:#3e8fb0,gutter:#232136 --color=spinner:#f6c177,info:#9ccfd8 --color=pointer:#c4a7e7,marker:#eb6f92,prompt:#908caa"
        # # Theme: Rose Pine Dawn
        # export FZF_DEFAULT_OPTS="--color=fg:#797593,bg:#faf4ed,hl:#d7827e --color=fg+:#575279,bg+:#f2e9e1,hl+:#d7827e --color=border:#dfdad9,header:#286983,gutter:#faf4ed --color=spinner:#ea9d34,info:#56949f --color=pointer:#907aa9,marker:#b4637a,prompt:#797593"
    fi
}

setup_luarocks() {
    # Ubuntu 22.04 LTS glibc version is too old to install recent luarocks.
    # Get glibc version and clean it
    local glibc_version=$(ldd --version 2>&1 | head -n1 | grep -oP '\d+\.\d+')
    glibc_version=$(echo "$glibc_version" | tr -d '\n' | tr -d ' ')  # Remove newlines and spaces
    
    # Convert versions to comparable integers (major * 100 + minor)
    local glibc_num=$(echo "$glibc_version" | awk -F. '{print $1 * 100 + $2}')
    local target_num=$((2 * 100 + 38))  # 2.38 as integer
    
    # Set luarocks version based on glibc version
    if (( glibc_num > target_num )); then
        LUAROCKS_VERSION="3.11.1"
    else
        LUAROCKS_VERSION="3.8.0"
    fi
    
    # Install
    if [[ ! -x "$XDG_PREFIX_HOME/bin/luarocks" ]] || \
       [[ "$($XDG_PREFIX_HOME/bin/luarocks --version | head -n 1 | cut -d ' ' -f 2)" != "$LUAROCKS_VERSION" ]]; then
        info "Installing the luarocks ${LUAROCKS_VERSION}"
        wget -q "https://luarocks.github.io/luarocks/releases/luarocks-${LUAROCKS_VERSION}-linux-x86_64.zip"
        unzip -qq "luarocks-${LUAROCKS_VERSION}-linux-x86_64.zip"
        cp luarocks-${LUAROCKS_VERSION}-linux-x86_64/luarocks* ${XDG_PREFIX_HOME}/bin && \
        rm -r luarocks-${LUAROCKS_VERSION}-linux-x86_64*

        # Check
        if [[ "$($XDG_PREFIX_HOME/bin/luarocks --version | head -n 1 | cut -d ' ' -f 2)" == "$LUAROCKS_VERSION" ]]; then
            completed "luarocks version: $LUAROCKS_VERSION"
        else
            error "Failed to install luarocks $LUAROCKS_VERSION"
        fi
    fi
}

setup_tpm() {
    if [[ ! -d "${XDG_PREFIX_HOME}/share/tmux/plugins/tpm" ]]; then
        info "Installing the latest tpm."
        git clone --depth 1 https://github.com/tmux-plugins/tpm ${XDG_PREFIX_HOME}/share/tmux/plugins/tpm 1>/dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            complete "Done."
        else 
            error "Failed to install tpm"
        fi
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
        # IMPORTANT: kitty-scrollback.nvim only supports zsh 5.9 or greater for command-line editing,
        # please check your version by running: zsh --version

        # add the following environment variables to your zsh config (e.g., ~/.zshrc)

        autoload -Uz edit-command-line
        zle -N edit-command-line

        function kitty_scrollback_edit_command_line() { 
          local VISUAL='${XDG_DATA_HOME}/nvim/lazy/kitty-scrollback.nvim/scripts/edit_command_line.sh'
          zle edit-command-line
          zle kill-whole-line
        }
        zle -N kitty_scrollback_edit_command_line

        bindkey '^x^e' kitty_scrollback_edit_command_line
        # [optional] pass arguments to kitty-scrollback.nvim in command-line editing mode
        # by using the environment variable KITTY_SCROLLBACK_NVIM_EDIT_ARGS
        # export KITTY_SCROLLBACK_NVIM_EDIT_ARGS=''
    else
        debug "kitty not found at ${XDG_PREFIX_HOME}/bin/kitty"
    fi
}

setup_wsl_notify_send() {
    if [[ $(uname -r) =~ WSL2 ]]; then
        # Install
        if [[ ! -x "$XDG_PREFIX_HOME/bin/wsl-notify-send.exe" ]]; then
            info "Installing the latest wsl-notify-send (x86_64)"
            pwddir=$(pwd)
            tmpdir=$(mktemp -d)
            cd "$tmpdir"
            curl -s "https://api.github.com/repos/stuartleeks/wsl-notify-send/releases/latest" | \
                grep 'browser_download_url.*wsl-notify-send_windows_amd64.zip' | \
                cut -d : -f 2,3 | \
                tr -d \" | \
                wget -qi -
            unzip -qq wsl-notify-send_windows_amd64.zip
            cp wsl-notify-send.exe $XDG_PREFIX_HOME/bin
            cd $pwddir
            rm -rf $tmpdir
            if [[ -x "$XDG_PREFIX_HOME/bin/wsl-notify-send.exe" ]]; then
                completed "wsl-notify-send version: $(wsl-notify-send.exe --version | head -n 1 | cut -d' ' -f3)"
            else
                error "Failed to install wsl-notify-send"
            fi
        fi
        # Load
        if [[ -x "$XDG_PREFIX_HOME/bin/wsl-notify-send.exe" ]]; then
            notify-send() { $XDG_PREFIX_HOME/bin/wsl-notify-send.exe --category $WSL_DISTRO_NAME "${@}"; }
        fi
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
setup_lazydocker
setup_yazi
setup_fzf
setup_luarocks
setup_kitty
setup_wsl_notify_send

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

safely_source "${HOME}/.secrets/ros.sh"
setup_ros2

setup_texlive

safely_source "${HOME}/.secrets/llm_api_keys.sh"

# echo "Type \"help\" to display supported handy commands."
zshrc_end_time=$(date +%s%N)
zshrc_duration=$(( (zshrc_end_time - zshrc_start_time) / 1000000 ))
info "$zshrc_duration ms$RESET to start up zsh."
