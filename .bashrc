# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
    *) return ;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color | *-256color) color_prompt=yes ;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
        # We have color support; assume it's compliant with Ecma-48
        # (ISO/IEC-6429). (Lack of such support is extremely rare, and such
        # a case would tend to support setf rather than setaf.)
        color_prompt=yes
    else
        color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
    xterm* | rxvt*)
        PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
        ;;
    *) ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

# ----- Customizations mirroring ~/.zshrc (portable and conditional) -----

# Load portable shell utilities
if [ -r "$HOME/.sh_utils/basics.sh" ]; then
    . "$HOME/.sh_utils/basics.sh"
else
    has() { command -v "$1" >/dev/null 2>&1; }
fi

# Provide zsh-compatible 'unfunction' in bash for sourced helpers
if [ -n "${BASH_VERSION:-}" ] && ! type unfunction >/dev/null 2>&1; then
    unfunction() { unset -f "$@"; }
fi

# Optional helpers
if type safely_source >/dev/null 2>&1; then
    safely_source "$HOME/.sh_utils/helpers.sh"
    safely_source "$HOME/.sh_utils/checkers.sh"
    safely_source "$HOME/.sh_utils/tools.sh"
fi

# Editors and git core.editor
if has nvim; then
    export SUDO_EDITOR=nvim
    export EDITOR=nvim
    if has git; then git config --global core.editor "nvim"; fi
elif has vim; then
    export SUDO_EDITOR=vim
    export EDITOR=vim
    if has git; then git config --global core.editor "vim"; fi
elif has vi; then
    export SUDO_EDITOR=vi
    export EDITOR=vi
    if has git; then git config --global core.editor "vi"; fi
fi

# Aliases (mapped from zsh)
alias zshconfig='${EDITOR} ${HOME}/.zshrc'
alias nvimconfig='${EDITOR} ${XDG_CONFIG_HOME}/nvim'
alias tmuxconfig='${EDITOR} ${XDG_CONFIG_HOME}/tmux'
alias sshconfig='${EDITOR} ${HOME}/.ssh/config'
alias aiconfig='${EDITOR} .aiderrules && ln -srf .aiderrules CLAUDE.md AGENTS.md'
alias aiderconfig='${EDITOR} ${HOME}/.aider.conf.yml'
alias starshipconfig='${EDITOR} ${XDG_CONFIG_HOME}/starship.toml'
alias kittyconfig='${EDITOR} $XDG_CONFIG_HOME/kitty/kitty.conf'
alias alacrittyconfig='${EDITOR} $XDG_CONFIG_HOME/alacritty/alacritty.toml'
alias ai='aider --watch-files'
alias cl='tput clear'
alias python='python3'
alias lg='lazygit'
alias t='tmux'
alias ta='tmux a'
alias cdusb='cd /media/$USER/"$(ls -t /media/$USER/ | head -n1)"'

export ARCHFLAGS="-arch $(uname -m)"
export NUMCPUS=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || getconf _NPROCESSORS_ONLN)
alias pmake='time nice make -j${NUMCPUS} --load-average=${NUMCPUS}'

# Bash options approximating zsh behavior
shopt -s extglob 2>/dev/null || true
shopt -s globstar 2>/dev/null || true
shopt -s dotglob 2>/dev/null || true
shopt -s autocd 2>/dev/null || true
shopt -s cdspell 2>/dev/null || true

# History timestamp similar to zsh's HIST_STAMPS
HISTTIMEFORMAT="%d/%m/%Y %T "

# Tool completions
has pixi && eval "$(pixi completion --shell bash)"
has gh && eval "$(gh completion -s bash)"
has uv && eval "$(uv generate-shell-completion bash)"

# Rust
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# Node.js
export NVM_DIR="${XDG_CONFIG_HOME}/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# Go
type prepend_env >/dev/null 2>&1 && prepend_env PATH "${HOME}/.local/go/bin"

# Deno
[ -f "$HOME/.deno/env" ] && . "$HOME/.deno/env"

# Google Drive Upload
type prepend_env >/dev/null 2>&1 && prepend_env PATH "${HOME}/.google-drive-upload/bin"

# yazi integration (cd to last dir on exit)
setup_yazi() {
    if has yazi; then
        y() {
            local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
            yazi "$@" --cwd-file="$tmp"
            if cwd="$(command cat -- "$tmp" 2>/dev/null)" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
                builtin cd -- "$cwd"
            fi
            rm -f -- "$tmp"
        }
    else
        [ "$(type -t warning 2>/dev/null)" ] && warning "yazi not found."
    fi
}
setup_yazi

# fzf integration and theme
if [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/fzf/fzf.bash" ]; then
    source "${XDG_CONFIG_HOME:-$HOME/.config}/fzf/fzf.bash"
elif [ -f "$HOME/.fzf.bash" ]; then
    source "$HOME/.fzf.bash"
fi
if has kitten; then
    export FZF_CTRL_R_OPTS="--bind 'ctrl-Y:execute-silent(echo -n {2..} | kitten clipboard)' --color header:italic --header 'Press CTRL-Y to copy command into clipboard'"
elif has wl-copy; then
    export FZF_CTRL_R_OPTS="--bind 'ctrl-Y:execute-silent(echo -n {2..} | wl-copy)' --color header:italic --header 'Press CTRL-Y to copy command into clipboard'"
elif has xclipboard; then
    export FZF_CTRL_R_OPTS="--bind 'ctrl-Y:execute-silent(echo -n {2..} | xclipboard -selection clipboard)' --color header:italic --header 'Press CTRL-Y to copy command into clipboard'"
fi
export FZF_ALT_C_OPTS="--walker-skip .git,node_modules,target --preview 'tree -C {}'"
export FZF_DEFAULT_OPTS="--color=fg:#797593,bg:#faf4ed,hl:#d7827e --color=fg+:#575279,bg+:#f2e9e1,hl+:#d7827e --color=border:#dfdad9,header:#286983,gutter:#faf4ed --color=spinner:#ea9d34,info:#56949f --color=pointer:#907aa9,marker:#b4637a,prompt:#797593"

# Bash vi-mode with jk escape
set -o vi
bind 'set editing-mode vi'
bind 'set keymap vi-insert'
bind '"jk":"\e"'

# Starship prompt (preferred)
has starship && eval "$(starship init bash)"

# ROS helpers (adapted to bash)
_guess_ros_distro() {
    local count=0 last=""
    if [ -d /opt/ros ]; then
        while IFS= read -r dir; do
            last="$(basename "$dir")"
            count=$((count+1))
        done < <(find /opt/ros -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
    fi
    if [ "$count" -eq 1 ] && [ -n "$last" ]; then
        printf "%s" "$last"; return 0
    fi
    return 1
}
setup_ros() {
    if [ -z "${ROS1_DISTRO}" ]; then
        local __guess; __guess=$(_guess_ros_distro) || true
        if [ -n "${__guess}" ]; then
            export ROS1_DISTRO="${__guess}"
            [ "$(type -t hint 2>/dev/null)" ] && hint "please specify environment variable \"ROS1_DISTRO\""
            [ "$(type -t hint 2>/dev/null)" ] && hint "make a guess here: ROS1_DISTRO=${ROS1_DISTRO}"
        fi
    fi
    if [ -n "${ROS1_DISTRO}" ] && [ -f "/opt/ros/${ROS1_DISTRO}/setup.bash" ]; then
        . "/opt/ros/${ROS1_DISTRO}/setup.bash"
        [ "$(type -t msg 2>/dev/null)" ] && msg "${BOLD}${UNDERLINE}${ICON_ROS}ROS $ROS1_DISTRO${RESET}"
    else
        [ "$(type -t hint 2>/dev/null)" ] && hint "make sure ROS is ready; please specify environment variable \"ROS1_DISTRO\""
    fi
}
setup_ros2() {
    if [ -z "${ROS2_DISTRO}" ]; then
        local __guess; __guess=$(_guess_ros_distro) || true
        if [ -n "${__guess}" ]; then
            export ROS2_DISTRO="${__guess}"
            [ "$(type -t hint 2>/dev/null)" ] && hint "please specify environment variable \"ROS2_DISTRO\""
            [ "$(type -t hint 2>/dev/null)" ] && hint "make a guess here: ROS2_DISTRO=${ROS2_DISTRO}"
        fi
    fi
    if [ -n "${ROS2_DISTRO}" ] && [ -f "/opt/ros/${ROS2_DISTRO}/setup.bash" ]; then
        [ "$(type -t msg 2>/dev/null)" ] && msg "${BOLD}${UNDERLINE}${ICON_ROS}ROS 2 $ROS2_DISTRO${RESET}"
        . "/opt/ros/${ROS2_DISTRO}/setup.bash"
        [ "$(type -t info 2>/dev/null)" ] && info "ROS2 Environment Variables:"
        [ "$(type -t info 2>/dev/null)" ] && info "ROS_VERSION=${ROS_VERSION}"
        [ "$(type -t info 2>/dev/null)" ] && info "ROS_PYTHON_VERSION=${ROS_PYTHON_VERSION}"
        [ "$(type -t info 2>/dev/null)" ] && info "ROS_DISTRO=${ROS_DISTRO}"
        [ "$(type -t info 2>/dev/null)" ] && info "ROS_DOMAIN_ID=${ROS_DOMAIN_ID}"
        [ "$(type -t info 2>/dev/null)" ] && info "ROS_LOCALHOST_ONLY=${ROS_LOCALHOST_ONLY}"
        if [ -f "/usr/share/colcon_cd/function/colcon_cd.sh" ]; then
            . "/usr/share/colcon_cd/function/colcon_cd.sh"
            export _colcon_cd_root="/opt/ros/${ROS_DISTRO}"
            [ "$(type -t success 2>/dev/null)" ] && success "colcon_cd"
        else
            [ "$(type -t warning 2>/dev/null)" ] && warning "colcon_cd not found."
            [ "$(type -t hint 2>/dev/null)" ] && hint "try 'sudo apt install python3-colcon-common-extensions'"
        fi
        if [ -f "/usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash" ]; then
            . "/usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash"
            [ "$(type -t success 2>/dev/null)" ] && success "colcon-argcomplete"
        else
            [ "$(type -t warning 2>/dev/null)" ] && warning "colcon-argcomplete.bash not found."
            [ "$(type -t hint 2>/dev/null)" ] && hint "try 'sudo apt install python3-colcon-common-extensions'"
        fi
    else
        [ "$(type -t hint 2>/dev/null)" ] && hint "make sure ROS2 is ready; please specify environment variable \"ROS2_DISTRO\""
    fi
}

# Wayland/X11 permission tweak
check_x11_wayland() {
    if [ "${XDG_SESSION_TYPE}" = "wayland" ]; then
        [ "$(type -t debug 2>/dev/null)" ] && debug "using wayland"
        local __xhost_command="xhost +SI:localuser:$(id -un) >/dev/null 2>&1"
        [ "$(type -t debug 2>/dev/null)" ] && debug "executing '$__xhost_command'"
        eval "$__xhost_command"
    fi
}
check_x11_wayland

# Network proxy helpers
type safely_source >/dev/null 2>&1 && safely_source "$HOME/.sh_utils/network_management.sh"
if [ -n "${VPN_PROTOCOL:-}" ] && has systemctl && systemctl is-active --quiet "sing-box-${VPN_PROTOCOL}.service" 2>/dev/null; then
    if has set_local_proxy; then set_local_proxy; else echo "error: command set_local_proxy not found"; fi
fi
