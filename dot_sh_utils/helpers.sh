#!/usr/bin/env bash

sshtmux() {
    local host="$1"
    local session_name="${2:-session-$(date +%Y-%m-%d)}"
    ssh "$host" -t "zsh -ic \"tmux a || tmux new -s '$session_name'\""
}
