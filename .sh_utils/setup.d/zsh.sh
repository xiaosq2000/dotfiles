#!/usr/bin/env bash

source ~/.sh_utils/basics.sh

# Install oh-my-zsh
/bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Install zsh plugins within oh-my-zsh
ZSH_CUSTOM=${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}

info "Installing the latest conda-zsh-completion"
git clone --depth 1 https://github.com/conda-incubator/conda-zsh-completion "${ZSH_CUSTOM}/plugins/conda-zsh-completion" 1>/dev/null 2>&1
if [[ $? -eq 0 ]]; then
    completed "Done"
else
    error "Failed"
fi

info "Installing the latest zsh-syntax-highlighting"
git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting" 1>/dev/null 2>&1
if [[ $? -eq 0 ]]; then
    completed "Done"
else
    error "Failed"
fi

info "Installing the latest zsh-autosuggestions"
git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions.git "${ZSH_CUSTOM}/plugins/zsh-autosuggestions" 1>/dev/null 2>&1
if [[ $? -eq 0 ]]; then
    completed "Done"
else
    error "Failed"
fi

info "Installing the latest zsh-autoenv"
git clone --depth 1 https://github.com/Tarrasch/zsh-autoenv "${ZSH_CUSTOM}/plugins/zsh-autoenv" 1>/dev/null 2>&1
if [[ $? -eq 0 ]]; then
    completed "Done"
else
    error "Failed"
fi

info "Installing the latest zsh-vi-mode"
git clone --depth 1 https://github.com/jeffreytse/zsh-vi-mode "${ZSH_CUSTOM}/plugins/zsh-vi-mode" 1>/dev/null 2>&1
if [[ $? -eq 0 ]]; then
    completed "Done"
else
    error "Failed"
fi

info "Installing the latest fzf-tab"
git clone --depth 1 https://github.com/Aloxaf/fzf-tab "${ZSH_CUSTOM}/plugins/fzf-tab" 1>/dev/null 2>&1
if [[ $? -eq 0 ]]; then
    completed "Done"
else
    error "Failed"
fi
