#!/usr/bin/env zsh
# zshrc_start_time=$(date +%s%N)

source ~/.sh_utils/basics.sh
source ~/.sh_utils/helpers.sh
source ~/.sh_utils/checkers.sh
source ~/.sh_utils/tools.sh

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

# precmd() {
#     echo;  # Add a newline
# }

# Aliases:
alias zshconfig="${EDITOR} ${HOME}/.zshrc"
alias nvimconfig="${EDITOR} ${XDG_CONFIG_HOME}/nvim"
alias tmuxconfig="${EDITOR} ${XDG_CONFIG_HOME}/tmux"
alias sshconfig="${EDITOR} ${HOME}/.ssh/config"
alias aiconfig="${EDITOR} .aiderrules && ln -srf .aiderrules CLAUDE.md AGENTS.md"
alias aiderconfig="${EDITOR} ${HOME}/.aider.conf.yml"
alias starshipconfig="${EDITOR} ${XDG_CONFIG_HOME}/starship.toml"
alias kittyconfig="${EDITOR} $XDG_CONFIG_HOME/kitty/kitty.conf"
alias alacrittyconfig="${EDITOR} $XDG_CONFIG_HOME/alacritty/alacritty.toml"
alias ai="aider --watch-files"
alias cl="tput clear"
alias python="python3"
alias lg="lazygit"
alias t="tmux"
alias ta="tmux a"
alias s='web_search google'
alias cdusb='cd /media/$USER/"$(ls -t /media/$USER/ | head -n1)"'
export ARCHFLAGS="-arch $(uname -m)"
export NUMCPUS=$(grep -c '^processor' /proc/cpuinfo)
alias pmake='time nice make -j${NUMCPUS} --load-average=${NUMCPUS}'

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
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

export ZSH="$HOME/.oh-my-zsh"
HIST_STAMPS="dd/mm/yyyy"

ZSH_CUSTOM=${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}

################################################################################
##################################### pixi #####################################
################################################################################
# https://github.com/prefix-dev/pixi/
prepend_env PATH "${HOME}/.pixi/bin"  # Add pixi to PATH first
if has pixi; then eval "$(pixi completion --shell zsh)"; fi  # pixi shell-completion

################################################################################
##################################### rust #####################################
################################################################################
[ -f "$HOME/.cargo/env" ] && \. "$HOME/.cargo/env"

################################################################################
################################### terminal ###################################
################################################################################
set_kitty_as_default() {
    local KITTY_BIN

    if has kitty; then
        KITTY_BIN="$(command -v kitty)"
    elif [ -x "${XDG_PREFIX_HOME}/bin/kitty" ]; then
        KITTY_BIN="${XDG_PREFIX_HOME}/bin/kitty"
    elif [ -x "/usr/bin/kitty" ]; then
        KITTY_BIN="/usr/bin/kitty"
    else
        warning "kitty not found"
        return
    fi

    # For gnome, set kitty as default terminal
    if has gsettings; then
        if gsettings set org.gnome.desktop.default-applications.terminal exec "$KITTY_BIN" 2>/dev/null; then
            debug "Set kitty as default terminal"
        else
            error "Failed to set kitty as default terminal"
        fi
    else
        warning "gsettings not found - cannot set kitty as default terminal"
    fi
}
if [ "$TERM" = "xterm-kitty" ] && has kitten; then
    # Set kitty-scrollback.nvim
    # NOTE: kitty-scrollback.nvim only supports zsh 5.9 or greater for command-line editing,
    autoload -Uz is-at-least
    if is-at-least 5.9; then
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
        warning "zsh < 5.9 detected; skipping kitty-scrollback.nvim command-line integration"
    fi
    # Set kitty's "Truly convenient SSH"
    alias ssh="kitten ssh"
fi
set_gnome_terminal_as_default() {
    local GNOME_TERMINAL_BIN

    if has gnome-terminal; then
        GNOME_TERMINAL_BIN="$(command -v gnome-terminal)"
    elif [ -x "/usr/bin/gnome-terminal" ]; then
        GNOME_TERMINAL_BIN="/usr/bin/gnome-terminal"
    else
        warning "gnome-terminal not found"
        return
    fi

    if has gsettings; then
        if gsettings set org.gnome.desktop.default-applications.terminal exec "$GNOME_TERMINAL_BIN" 2>/dev/null; then
            debug "Set gnome-terminal as default terminal"
        else
            error "Failed to set gnome-terminal as default terminal"
        fi
    else
        warning "gsettings not found - cannot set gnome-terminal as default terminal"
    fi
}

################################################################################
################## yazi - Blazing fast terminal file manager ###################
########################## https://yazi-rs.github.io/ ##########################
################################################################################
setup_yazi() {
    if has yazi; then
    	function y() {
    		local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    		yazi "$@" --cwd-file="$tmp"
    		if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    			builtin cd -- "$cwd"
    		fi
    		rm -f -- "$tmp"
    	}
    else
        warning "yazi not found."
    fi
}
setup_yazi

################################################################################
###################### fzf - A command-line fuzzy finder #######################
####################### https://junegunn.github.io/fzf/  #######################
################################################################################
setup_fzf() {
    if [ -f "${XDG_CONFIG_HOME:-$HOME/.config}"/fzf/fzf.zsh ]; then
        source "${XDG_CONFIG_HOME:-$HOME/.config}"/fzf/fzf.zsh
        if has kitten; then
            export FZF_CTRL_R_OPTS="--bind 'ctrl-Y:execute-silent(echo -n {2..} | kitten clipboard)' --color header:italic --header 'Press CTRL-Y to copy command into clipboard'"
        elif has wl-copy; then
            export FZF_CTRL_R_OPTS="--bind 'ctrl-Y:execute-silent(echo -n {2..} | wl-copy)' --color header:italic --header 'Press CTRL-Y to copy command into clipboard'"
        elif has xclipboard; then
            export FZF_CTRL_R_OPTS="--bind 'ctrl-Y:execute-silent(echo -n {2..} | xclipboard -selection clipboard)' --color header:italic --header 'Press CTRL-Y to copy command into clipboard'"
        fi
        # Print tree structure in the preview window
        export FZF_ALT_C_OPTS="--walker-skip .git,node_modules,target --preview 'tree -C {}'"
        # Theme: Rose Pine Main
        # export FZF_DEFAULT_OPTS="--color=fg:#908caa,bg:#191724,hl:#ebbcba --color=fg+:#e0def4,bg+:#26233a,hl+:#ebbcba --color=border:#403d52,header:#31748f,gutter:#191724 --color=spinner:#f6c177,info:#9ccfd8 --color=pointer:#c4a7e7,marker:#eb6f92,prompt:#908caa"
        # Theme: Rose Pine Moon
        # export FZF_DEFAULT_OPTS="--color=fg:#908caa,bg:#232136,hl:#ea9a97 --color=fg+:#e0def4,bg+:#393552,hl+:#ea9a97 --color=border:#44415a,header:#3e8fb0,gutter:#232136 --color=spinner:#f6c177,info:#9ccfd8 --color=pointer:#c4a7e7,marker:#eb6f92,prompt:#908caa"
        # Theme: Rose Pine Dawn
        export FZF_DEFAULT_OPTS="--color=fg:#797593,bg:#faf4ed,hl:#d7827e --color=fg+:#575279,bg+:#f2e9e1,hl+:#d7827e --color=border:#dfdad9,header:#286983,gutter:#faf4ed --color=spinner:#ea9d34,info:#56949f --color=pointer:#907aa9,marker:#b4637a,prompt:#797593"
    else
        warning "fzf not found."
    fi
}

################################################################################
###### fzf-tab - Replace zsh's default completion selection menu with fzf ######
###################### https://github.com/Aloxaf/fzf-tab #######################
################################################################################
setup_fzf_tab() {
    # disable sort when completing `git checkout`
    zstyle ':completion:*:git-checkout:*' sort false
    # set descriptions format to enable group support
    # NOTE: don't use escape sequences (like '%F{red}%d%f') here, fzf-tab will ignore them
    zstyle ':completion:*:descriptions' format '[%d]'
    # set list-colors to enable filename colorizing
    zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
    # force zsh not to show completion menu, which allows fzf-tab to capture the unambiguous prefix
    zstyle ':completion:*' menu no
    # preview directory's content with eza when completing cd
    zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
    # custom fzf flags
    # NOTE: fzf-tab does not follow FZF_DEFAULT_OPTS by default
    zstyle ':fzf-tab:*' fzf-flags --color=fg:1,fg+:2 --bind=tab:accept
    # To make fzf-tab follow FZF_DEFAULT_OPTS.
    # NOTE: This may lead to unexpected behavior since some flags break this plugin. See Aloxaf/fzf-tab#455.
    zstyle ':fzf-tab:*' use-fzf-default-opts yes
    # switch group using `<` and `>`
    zstyle ':fzf-tab:*' switch-group '<' '>'
}
setup_fzf_tab

################################################################################
####### zsh-vi-mode - A better and friendly vi(vim) mode plugin for ZSH ########
################## https://github.com/jeffreytse/zsh-vi-mode ###################
################################################################################
# ref: https://github.com/jeffreytse/zsh-vi-mode?tab=readme-ov-file#configuration-function
zvm_config() {
    ZVM_VI_INSERT_ESCAPE_BINDKEY=jk
    ZVM_SYSTEM_CLIPBOARD_ENABLED=true
    # Solve the conflicts with fzf
    # ref: https://github.com/jeffreytse/zsh-vi-mode?tab=readme-ov-file#execute-extra-commands
    zvm_after_init_commands+=('setup_fzf')
}
source "$ZSH_CUSTOM/plugins/zsh-vi-mode/zsh-vi-mode.zsh"

plugins=(
    conda-zsh-completion
    docker
    docker-compose
    dotenv
    fzf-tab  # fzf-tab needs to be loaded after compinit, but before plugins which will wrap widgets, such as zsh-autosuggestions or fast-syntax-highlighting
    gh
    git
    git-auto-fetch
    git-lfs
    pre-commit
    ssh
    web-search
    zsh-autosuggestions
    zsh-ssh
    zsh-syntax-highlighting
    zsh-vi-mode
)

source $ZSH/oh-my-zsh.sh

# nodejs
export NVM_DIR="${XDG_CONFIG_HOME}/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# go
prepend_env PATH "${HOME}/.local/go/bin"

# deno
[ -f "$HOME/.deno/env" ] && \. "$HOME/.deno/env"

# starship
if has starship; then eval "$(starship init zsh)"; fi

# google-drive-upload
prepend_env PATH "${HOME}/.google-drive-upload/bin"

# tre
tre() { command tre "$@" -e && source "/tmp/tre_aliases_$USER" 2>/dev/null; }

# uv shell completion
if has uv; then eval "$(uv generate-shell-completion zsh)"; fi

check_git_config() {
    if has "git"; then
        if [[ ! -f $HOME/.gitconfig ]]; then
            touch $HOME/.gitconfig
        fi
        if [[ ! $(cat $HOME/.gitconfig | grep 'email') ]]; then
            hint "git config --global user.email \"<YOUR_EMAIL>\""
        fi
        if [[ ! $(cat $HOME/.gitconfig | grep 'name') ]]; then
            hint "git config --global user.name \"<YOUR_NAME>\""
        fi
    fi
}
check_git_config

check_x11_wayland() {
    if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
        debug "using wayland"
        # reference: https://unix.stackexchange.com/a/359244/523957
        __xhost_command="xhost +SI:localuser:$(id -un) >/dev/null 2>&1"
        debug "executing '$__xhost_command'"
        eval "$__xhost_command"
    fi
}
check_x11_wayland

setup_texlive() {
    TEXLIVE_VERSION=2025
    if [[ -d "${XDG_DATA_HOME}/../texlive/${TEXLIVE_VERSION}/bin/x86_64-linux" ]]; then
        append_env PATH "${XDG_DATA_HOME}/../texlive/${TEXLIVE_VERSION}/bin/x86_64-linux"
        debug "using texlive $TEXLIVE_VERSION"
    elif [[ -d "${XDG_PREFIX_DIR}/texlive/${TEXLIVE_VERSION}" ]]; then
        append_env PATH "${XDG_PREFIX_DIR}/texlive/${TEXLIVE_VERSION}/texmf-dist/doc/info"
        append_env PATH "${XDG_PREFIX_DIR}/texlive/${TEXLIVE_VERSION}/texmf-dist/doc/man"
        append_env PATH "${XDG_PREFIX_DIR}/texlive/${TEXLIVE_VERSION}/bin/x86_64-linux"
        debug "using texlive $TEXLIVE_VERSION"
    else
        debug "texlive $TEXLIVE_VERSION not found"
    fi
}
setup_texlive

search_typefaces() {
    # reference: https://stackoverflow.com/a/49313231/11393911
    fc-list -f "%{family}\n" | rg -i "$1" | sort -t: -u -k1,1
    if [ -z "$1" ]; then
        hint "example: $0 fira"
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

# network proxy
source ~/.sh_utils/network_management.sh
if [ -n VPN_PROTOCOL ] && has systemctl && systemctl is-active --quiet "sing-box-$VPN_PROTOCOL.service" 2>/dev/null; then
    if has set_local_proxy; then set_local_proxy; else error "command set_local_proxy not found"; fi
    # if has check_public_ip; then check_public_ip; else error "command check_public_ip not found"; fi
fi

# zshrc_end_time=$(date +%s%N)
# zshrc_duration=$(( (zshrc_end_time - zshrc_start_time) / 1000000 ))
# DEBUG=1 debug "$zshrc_duration ms$RESET to start up zsh."
