#!/usr/bin/env zsh
# zshrc_start_time=$(date +%s%N)

source ~/.sh_utils/basics.sh
source ~/.sh_utils/helpers.sh
source ~/.sh_utils/checkers.sh
source ~/.sh_utils/network_management.sh
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

# Aliases:
alias ohmyzsh="${EDITOR} ${HOME}/.oh-my-zsh"
alias zshconfig="${EDITOR} ${HOME}/.zshrc"
alias nvimconfig="${EDITOR} ${XDG_CONFIG_HOME}/nvim"
alias tmuxconfig="${EDITOR} ${XDG_CONFIG_HOME}/tmux"
alias sshconfig="${EDITOR} ${HOME}/.ssh/config"
alias aiconfig="${EDITOR} .aiderrules && ln -srf .aiderrules CLAUDE.md"
alias aiderconfig="${EDITOR} ${HOME}/.aider.conf.yml"
alias starshipconfig="${EDITOR} ${XDG_CONFIG_HOME}/starship.toml"
alias kittyconfig="${EDITOR} $XDG_CONFIG_HOME/kitty/kitty.conf"
alias alacrittyconfig="${EDITOR} $XDG_CONFIG_HOME/alacritty/alacritty.toml"

alias cl="tput clear"

alias e='$EDITOR'
alias v='$EDITOR'

alias python="python3"
alias lg="lazygit"

alias t="tmux"
alias ta="tmux a"

alias s='web_search google'
# alias s='kitten ssh'

alias cdusb='cd /media/$USER/"$(ls -t /media/$USER/ | head -n1)"'

alias ai="aider --watch-files"

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
################################ kitty terminal ################################
################################################################################
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

        # Execute the following only if zsh >= 5.9, AI!
        # IMPORTANT: kitty-scrollback.nvim only supports zsh 5.9 or greater for command-line editing,
        # please check your version by running: zsh --version

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
    else
        debug "kitty not found at ${XDG_PREFIX_HOME}/bin/kitty"
    fi
    if [[ "$TERM" == "xterm-kitty" ]]; then
        alias ssh="kitten ssh"
    fi
}
setup_kitty

################################################################################
##################################### node #####################################
################################################################################
export NVM_DIR="${XDG_CONFIG_HOME}/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

################################################################################
################################### starship ###################################
################################################################################
eval "$(starship init zsh)"

################################################################################
##################################### rust #####################################
################################################################################
[ -f "$HOME/.cargo/env" ] && \. "$HOME/.cargo/env"

################################################################################
##################################### deno #####################################
################################################################################
[ -f "$HOME/.deno/env" ] && \. "$HOME/.deno/env"

prepend_env PATH "${HOME}/.google-drive-upload/bin"

################################################################################
##################################### pixi #####################################
################################################################################
# https://github.com/prefix-dev/pixi/
# Installation: curl -fsSL https://pixi.sh/install.sh | PIXI_NO_PATH_UPDATE=1 bash
# Add pixi to PATH first
prepend_env PATH "${HOME}/.pixi/bin"
# pixi shell-completion
if has pixi; then eval "$(pixi completion --shell zsh)"; fi

################################################################################
##################################### yazi #####################################
################################################################################
if [ -x "$XDG_PREFIX_HOME/bin/yazi" ]; then
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

################################################################################
########################## zsh-vi-mode configuration ###########################
################################################################################
# ref: https://github.com/jeffreytse/zsh-vi-mode?tab=readme-ov-file#configuration-function
zvm_config() {
    ZVM_VI_INSERT_ESCAPE_BINDKEY=jk
    # Solve the conflicts with fzf
    # https://github.com/jeffreytse/zsh-vi-mode?tab=readme-ov-file#execute-extra-commands
    zvm_after_init_commands+=('[ -f "${XDG_CONFIG_HOME:-$HOME/.config}"/fzf/fzf.zsh ] && source "${XDG_CONFIG_HOME:-$HOME/.config}"/fzf/fzf.zsh')
}

source "$ZSH_CUSTOM/plugins/zsh-vi-mode/zsh-vi-mode.zsh"

################################################################################
############################ fzf-tab configuration #############################
################################################################################
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

# source "${XDG_CONFIG_HOME}/zsh/catppuccin_latte-zsh-syntax-highlighting.zsh"
# source "${ZSH_CUSTOM}/plugins/zsh-autoenv/autoenv.zsh"

plugins=(
    conda-zsh-completion
    docker
    docker-compose
    dotenv
    fzf-tab
    git
    git-auto-fetch
    web-search
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-vi-mode
)

source $ZSH/oh-my-zsh.sh

if [ -f "${XDG_CONFIG_HOME:-$HOME/.config}"/fzf/fzf.zsh ]; then
    source "${XDG_CONFIG_HOME:-$HOME/.config}"/fzf/fzf.zsh
    if has kitten; then
        export FZF_CTRL_R_OPTS="--bind 'ctrl-y:execute-silent(echo -n {2..} | kitten clipboard)' --color header:italic --header 'Press CTRL-Y to copy command into clipboard'"
    elif has wl-copy; then
        export FZF_CTRL_R_OPTS="--bind 'ctrl-y:execute-silent(echo -n {2..} | wl-copy)' --color header:italic --header 'Press CTRL-Y to copy command into clipboard'"
    elif has xclipboard; then
        export FZF_CTRL_R_OPTS="--bind 'ctrl-y:execute-silent(echo -n {2..} | xclipboard -selection clipboard)' --color header:italic --header 'Press CTRL-Y to copy command into clipboard'"
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

# Add a newline
precmd() {
    echo
}

check_git_config
check_x11_wayland

setup_texlive

if systemctl is-active --quiet "sing-box-$PROTOCOL.service" 2>/dev/null; then
    FORCE_LANG=zh_CN set_local_proxy
    FORCE_LANG=zh_CN check_public_ip 3
fi

# echo "Type \"help\" to display supported handy commands."
# zshrc_end_time=$(date +%s%N)
# zshrc_duration=$(( (zshrc_end_time - zshrc_start_time) / 1000000 ))
# info "$zshrc_duration ms$RESET to start up zsh."
