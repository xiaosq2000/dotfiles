#!/usr/bin/env bash
source ~/.sh_utils/basics.sh

info "Installing the latest lazygit"
LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
curl -sS --no-progress-meter -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar zxf lazygit.tar.gz lazygit
install -Dm 755 lazygit ${XDG_PREFIX_HOME}/bin
rm lazygit.tar.gz lazygit
if [ $? -eq 0 ]; then
    completed "lazygit version: $($XDG_PREFIX_HOME/bin/lazygit --version | cut -d ',' -f 4 | cut -d '=' -f 2)"
else
    error "Failed to install lazygit"
    exit 1
fi

info "Installing the latest difft"
curl -sS --no-progress-meter -Lo difft.tar.gz "https://github.com/Wilfred/difftastic/releases/latest/download/difft-x86_64-unknown-linux-gnu.tar.gz"
tar zxf difft.tar.gz
install -Dm 755 difft ${XDG_PREFIX_HOME}/bin
rm difft.tar.gz difft
if [ $? -eq 0 ]; then
    completed "difft version: $($XDG_PREFIX_HOME/bin/difft --version | head -n 1 | cut -d ' ' -f 2)"
else
    error "Failed to install difft"
    exit 1
fi
