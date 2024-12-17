# if [ -f "/etc/profile.d/modules.sh" ]; then
#     source "/etc/profile.d/modules.sh"
#     module load slurm
# fi

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

prepend_to_env_var() {
	local env_var_name="$1"
	shift
	local args=("$@")

	if [ -z "${!env_var_name}" ]; then
		export "$env_var_name"=""
	fi

	for ((i = ${#args[@]} - 1; i >= 0; i--)); do
		dir="${args[i]}"
		if [ -d "$dir" ] && ! [[ ":${!env_var_name}:" =~ :$dir: ]]; then
			if [ -z "${!env_var_name}" ]; then
				eval "export $env_var_name=\"$dir\""
			else
				eval "export $env_var_name=\"$dir:\${$env_var_name}\""
			fi
		fi
	done
}

append_to_env_var() {
	local env_var_name="$1"
	shift
	local args=("$@")

	if [ -z "${!env_var_name}" ]; then
		export "$env_var_name"=""
	fi

	for dir in "${args[@]}"; do
		if [ -d "$dir" ] && ! [[ ":${!env_var_name}:" =~ :$dir: ]]; then
			if [ -z "${!env_var_name}" ]; then
				eval "export $env_var_name=\"$dir\""
			else
				eval "export $env_var_name=\"\${$env_var_name}:$dir\""
			fi
		fi
	done
}

remove_from_env_var() {
	local env_var_name="$1"
	local path_to_remove="$2"
	local current_value="${!env_var_name}"

	current_value="${current_value//:$path_to_remove:/:}"
	current_value="${current_value//:$path_to_remove/}"
	current_value="${current_value//$path_to_remove:/}"

	eval "export $env_var_name=\"$current_value\""
}

prepend_to_env_var PATH "$HOME/.local/bin" "/usr/local/bin"
prepend_to_env_var LD_LIBRARY_PATH "$HOME/.local/lib" "/usr/local/lib"
prepend_to_env_var MANPATH "$HOME/.local/man" "/usr/local/man"

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

# Preferred editor
if command -v nvim &>/dev/null; then
	export SUDO_EDITOR='nvim'
	export EDITOR='nvim'
elif command -v vim &>/dev/null; then
	export SUDO_EDITOR='vim'
	export EDITOR='vim'
elif command -v vi &>/dev/null; then
	export SUDO_EDITOR='vi'
	export EDITOR='vi'
fi

# Compilation
export ARCHFLAGS="-arch $(uname -m)"
export NUMCPUS=$(grep -c '^processor' /proc/cpuinfo)
alias pmake='time nice make -j${NUMCPUS} --load-average=${NUMCPUS}'

# aliases
alias python="python3"
alias lg="lazygit"

alias nvimconfig="${EDITOR} ${XDG_CONFIG_HOME}/nvim"
alias tmuxconfig="${EDITOR} ${XDG_CONFIG_HOME}/tmux"
alias bashconfig="${EDITOR} ~/.bashrc"
alias sshconfig="${EDITOR} ${XDG_CONFIG_HOME}/.ssh/config"

# nvm
export NVM_DIR="${XDG_CONFIG_HOME}/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

# starship
eval "$(starship init bash)"
# Network proxy management configuration
source /home/shuqixiao/Projects/sing-box-docker/scripts/setup.bash

# Network proxy management configuration
[ -f ~/.network_management.sh ] && source ~/.network_management.sh
