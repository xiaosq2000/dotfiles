#!/bin/bash

# Script to install dotfiles from https://github.com/xiaosq2000/dotfiles
# Modified to work in both interactive and headless environments
#
# Usage:
#   Direct execution:
#     bash install.sh [OPTIONS]
#
#   One-liner with curl:
#     curl -fsSL "https://raw.githubusercontent.com/xiaosq2000/dotfiles/main/.sh_utils/install.sh" | bash -s -- [OPTIONS]
#
#   Examples:
#     curl -fsSL "https://raw.githubusercontent.com/xiaosq2000/dotfiles/main/.sh_utils/install.sh" | bash -s -- -y
#     curl -fsSL "https://raw.githubusercontent.com/xiaosq2000/dotfiles/main/.sh_utils/install.sh" | bash -s -- -y --with-binaries

set -e # Exit immediately if a command exits with a non-zero status

# Parse command-line arguments
SKIP_CONFIRMATION=false
INSTALL_BINARIES=false
for arg in "$@"; do
    case $arg in
        -y|--yes)
            SKIP_CONFIRMATION=true
            shift
            ;;
        --with-binaries)
            INSTALL_BINARIES=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -y, --yes           Skip confirmation prompt and proceed with installation"
            echo "  --with-binaries     Install additional binaries (e.g., uv, pixi, Neovim, Starship, node, fzf, yazi, plugins/tools for zsh and git)"
            echo "  -h, --help          Show this help message"
            echo ""
            echo "When using with curl, pass arguments like this:"
            echo "  curl -fsSL \"URL\" | bash -s -- [OPTIONS]"
            echo ""
            echo "Examples:"
            echo "  curl -fsSL \"URL\" | bash -s -- -y"
            echo "  curl -fsSL \"URL\" | bash -s -- -y --with-binaries"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Determine if script is being piped (e.g., from curl)
if [ ! -f "${BASH_SOURCE[0]}" ]; then
    # Script is being piped, download ui.sh to a temporary location
    TEMP_DIR=$(mktemp -d)
    UI_LIB="$TEMP_DIR/ui.sh"
    curl -fsSL "https://raw.githubusercontent.com/xiaosq2000/dotfiles/main/.sh_utils/lib/ui.sh" -o "$UI_LIB"
    CLEANUP_TEMP=true
else
    # Script is being executed directly
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    UI_LIB="$SCRIPT_DIR/lib/ui.sh"
    CLEANUP_TEMP=false
fi

# Source the UI library
source "$UI_LIB"

# Function to prompt for confirmation
confirm_installation() {
    echo ""
    warning "BACKUP FIRST! All your dotfiles will be REPLACED."
    echo ""
    info "This will overwrite existing configuration files in your home directory."
    info "Make sure you have backed up any important dotfiles before proceeding."
    echo ""

    read -p "Do you want to continue? (yes/no): " response

    case "$response" in
        [yY][eE][sS]|[yY])
            success "Proceeding with installation..."
            return 0
            ;;
        *)
            error "Installation cancelled."
            exit 0
            ;;
    esac
}

# Cleanup function
cleanup() {
    if [ "$CLEANUP_TEMP" = true ] && [ -n "${TEMP_DIR:-}" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Header
header "DOTFILES INSTALLER - https://github.com/xiaosq2000/dotfiles"

# Prompt for confirmation in interactive mode (unless skipped)
if [ "$INTERACTIVE" = true ] && [ "$SKIP_CONFIRMATION" = false ]; then
    confirm_installation
elif [ "$SKIP_CONFIRMATION" = true ]; then
    info "Skipping confirmation (--yes flag provided)"
fi

# Change to home directory
step "Changing to home directory"
cd ~
success "Changed to home directory: $(pwd)"

# Initialize git repository
step "Initializing git repository in home directory"
git init >/dev/null 2>&1 &
pid=$!
spinner $pid
success "Git repository initialized"

# Add remote origin
step "Adding remote origin"
git remote add origin https://github.com/xiaosq2000/dotfiles >/dev/null 2>&1 &
pid=$!
spinner $pid
success "Remote origin added"

# Fetch all branches
step "Fetching all branches (this may take a moment)"
git fetch --all >/dev/null 2>&1 &
pid=$!
spinner $pid
success "All branches fetched"

# Reset to match origin/main
step "Resetting to origin/main"
git reset --hard origin/main >/dev/null 2>&1 &
pid=$!
spinner $pid
success "Reset to origin/main complete"

# Rename branch to main
step "Renaming branch to main"
git branch -M main >/dev/null 2>&1 &
pid=$!
spinner $pid
success "Branch renamed to main"

# Set upstream branch
step "Setting upstream branch"
git branch -u origin/main main >/dev/null 2>&1 &
pid=$!
spinner $pid
success "Upstream branch set"

# Initialize all submodules
step "Initializing git submodules (optional)"
if git submodule update --init ~/.config/themes/rose-pine/starship >/dev/null 2>&1; then
    success "starship's rose-pine theme initialized"
else
    warning "Skipping submodule initialization due to an error (continuing)"
fi

# Install binaries if requested
if [ "$INSTALL_BINARIES" = true ]; then
    step "Installing additional binaries"

    # Check if neovim setup script exists
    NEOVIM_SCRIPT="$HOME/.sh_utils/setup.d/neovim.sh"
    if [ -f "$NEOVIM_SCRIPT" ]; then
        info "Running Neovim installation script..."

        # Make script executable and run it
        chmod +x "$NEOVIM_SCRIPT"
        if bash "$NEOVIM_SCRIPT"; then
            success "Neovim installed successfully"
        else
            warning "Neovim installation encountered an error"
        fi
    else
        warning "Neovim setup script not found at $NEOVIM_SCRIPT"
    fi

    # Check if git tools setup script exists
    GIT_SCRIPT="$HOME/.sh_utils/setup.d/git.sh"
    if [ -f "$GIT_SCRIPT" ]; then
        info "Running Git tools installation script..."

        # Make script executable and run it
        chmod +x "$GIT_SCRIPT"
        if bash "$GIT_SCRIPT"; then
            success "Git tools (lazygit, difftastic) installed successfully"
        else
            warning "Git tools installation encountered an error"
        fi
    else
        warning "Git tools setup script not found at $GIT_SCRIPT"
    fi

    # Check if starship setup script exists
    STARSHIP_SCRIPT="$HOME/.sh_utils/setup.d/starship.sh"
    if [ -f "$STARSHIP_SCRIPT" ]; then
        info "Running Starship installation script..."

        # Make script executable and run it
        chmod +x "$STARSHIP_SCRIPT"
        if bash "$STARSHIP_SCRIPT"; then
            success "Starship installed successfully"
        else
            warning "Starship installation encountered an error"
        fi
    else
        warning "Starship setup script not found at $STARSHIP_SCRIPT"
    fi

    # Check if node setup script exists
    NODE_SCRIPT="$HOME/.sh_utils/setup.d/node.sh"
    if [ -f "$NODE_SCRIPT" ]; then
        info "Running Node.js installation script..."

        # Make script executable and run it
        chmod +x "$NODE_SCRIPT"
        if bash "$NODE_SCRIPT"; then
            success "Node.js (nvm, node, tree-sitter) installed successfully"
        else
            warning "Node.js installation encountered an error"
        fi
    else
        warning "Node.js setup script not found at $NODE_SCRIPT"
    fi

    # Check if uv setup script exists
    UV_SCRIPT="$HOME/.sh_utils/setup.d/uv.sh"
    if [ -f "$UV_SCRIPT" ]; then
        info "Running uv installation script..."

        # Make script executable and run it
        chmod +x "$UV_SCRIPT"
        if bash "$UV_SCRIPT"; then
            success "uv installed successfully"
        else
            warning "uv installation encountered an error"
        fi
    else
        warning "uv setup script not found at $UV_SCRIPT"
    fi

    # Check if aider setup script exists
    AIDER_SCRIPT="$HOME/.sh_utils/setup.d/aider.sh"
    if [ -f "$AIDER_SCRIPT" ]; then
        info "Running Aider installation script..."

        # Make script executable and run it
        chmod +x "$AIDER_SCRIPT"
        if bash "$AIDER_SCRIPT"; then
            success "Aider installed successfully"
        else
            warning "Aider installation encountered an error"
        fi
    else
        warning "Aider setup script not found at $AIDER_SCRIPT"
    fi

    # Check if pixi setup script exists
    PIXI_SCRIPT="$HOME/.sh_utils/setup.d/pixi.sh"
    if [ -f "$PIXI_SCRIPT" ]; then
        info "Running pixi installation script..."

        # Make script executable and run it
        chmod +x "$PIXI_SCRIPT"
        if bash "$PIXI_SCRIPT"; then
            success "pixi installed successfully"
        else
            warning "pixi installation encountered an error"
        fi
    else
        warning "pixi setup script not found at $PIXI_SCRIPT"
    fi

    # Check if fzf setup script exists
    FZF_SCRIPT="$HOME/.sh_utils/setup.d/fzf.sh"
    if [ -f "$FZF_SCRIPT" ]; then
        info "Running fzf installation script..."

        # Make script executable and run it
        chmod +x "$FZF_SCRIPT"
        if bash "$FZF_SCRIPT"; then
            success "fzf installed successfully"
        else
            warning "fzf installation encountered an error"
        fi
    else
        warning "fzf setup script not found at $FZF_SCRIPT"
    fi

    # Check if yazi setup script exists
    YAZI_SCRIPT="$HOME/.sh_utils/setup.d/yazi.sh"
    if [ -f "$YAZI_SCRIPT" ]; then
        info "Running yazi installation script..."

        # Make script executable and run it
        chmod +x "$YAZI_SCRIPT"
        if bash "$YAZI_SCRIPT"; then
            success "yazi installed successfully"
        else
            warning "yazi installation encountered an error"
        fi
    else
        warning "yazi setup script not found at $YAZI_SCRIPT"
    fi

    # Check if zsh setup script exists
    ZSH_SCRIPT="$HOME/.sh_utils/setup.d/zsh.sh"
    if [ -f "$ZSH_SCRIPT" ]; then
        info "Running zsh installation script..."

        # Make script executable and run it
        chmod +x "$ZSH_SCRIPT"
        if bash "$ZSH_SCRIPT"; then
            success "zsh (oh-my-zsh and plugins) installed successfully"
        else
            warning "zsh installation encountered an error"
        fi
    else
        warning "zsh setup script not found at $ZSH_SCRIPT"
    fi
else
    info "Skipping binary installation (use --with-binaries to install)"
fi

# Footer
footer "INSTALLATION COMPLETE!"
success "Your dotfiles have been successfully installed!"
