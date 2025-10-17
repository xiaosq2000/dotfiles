#!/usr/bin/env bash

# Determine the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UI_LIB="$SCRIPT_DIR/../lib/ui.sh"

# Source the UI library
source "$UI_LIB"

header "oh-my-zsh - https://ohmyz.sh/"

# Install oh-my-zsh if not already installed
ZSH="${ZSH:-${HOME}/.oh-my-zsh}"
if [ -f "$ZSH/oh-my-zsh.sh" ]; then
    info "oh-my-zsh already installed at $ZSH"
else
    step "installing oh-my-zsh"
    if (unset ZSH; /bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc >/dev/null 2>&1); then
        success "oh-my-zsh installed successfully"
    else
        error "failed to install oh-my-zsh"
        exit 1
    fi
fi

# Install zsh plugins within oh-my-zsh
ZSH_CUSTOM=${ZSH_CUSTOM:-${ZSH}/custom}

if [ -f "$ZSH/oh-my-zsh.sh" ]; then
    step "installing zsh plugins"

    # Helper to clone or update a plugin repository
    clone_or_update() {
        local repo_url="$1"
        local plugin_dir="$2"
        local display_name="${3:-$(basename "$plugin_dir")}"

        info "installing or updating ${display_name}..."
        if [ -d "$plugin_dir" ]; then
            if [ -d "$plugin_dir/.git" ]; then
                if git -C "$plugin_dir" fetch --quiet >/dev/null 2>&1 && git -C "$plugin_dir" pull --ff-only --quiet >/dev/null 2>&1; then
                    success "${display_name} updated"
                else
                    warning "failed to update ${display_name} (please check repository state)"
                fi
            else
                warning "${display_name} exists but is not a git repository; skipping update"
            fi
        else
            if git clone --depth 1 "$repo_url" "$plugin_dir" >/dev/null 2>&1; then
                success "${display_name} installed"
            else
                warning "failed to install ${display_name}"
            fi
        fi
    }

    clone_or_update "https://github.com/conda-incubator/conda-zsh-completion" "${ZSH_CUSTOM}/plugins/conda-zsh-completion" "conda-zsh-completion"
    clone_or_update "https://github.com/zsh-users/zsh-syntax-highlighting.git" "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting" "zsh-syntax-highlighting"
    clone_or_update "https://github.com/zsh-users/zsh-autosuggestions.git" "${ZSH_CUSTOM}/plugins/zsh-autosuggestions" "zsh-autosuggestions"
    # clone_or_update "https://github.com/Tarrasch/zsh-autoenv" "${ZSH_CUSTOM}/plugins/zsh-autoenv" "zsh-autoenv"
    clone_or_update "https://github.com/jeffreytse/zsh-vi-mode" "${ZSH_CUSTOM}/plugins/zsh-vi-mode" "zsh-vi-mode"
    clone_or_update "https://github.com/Aloxaf/fzf-tab" "${ZSH_CUSTOM}/plugins/fzf-tab" "fzf-tab"
else
    warning "oh-my-zsh not installed; skipping zsh plugin installation"
fi

footer "oh-my-zsh - https://ohmyz.sh/"
