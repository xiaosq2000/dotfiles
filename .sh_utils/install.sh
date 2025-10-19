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
            echo "  --with-binaries     Install additional binaries (will prompt in interactive mode if not specified)"
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
# shellcheck disable=SC1090
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

# Function to prompt for binaries
confirm_binary_installation() {
    echo ""
    info "Optional: Install additional developer binaries (Neovim, Git tools, Node.js, Rust, uv, pixi, Aider, fzf, yazi, zsh, typefaces)."
    echo ""
    read -p "Do you want to install additional binaries? (yes/no): " response
    case "$response" in
        [yY][eE][sS]|[yY])
            success "Will install additional binaries..."
            return 0
            ;;
        *)
            info "You chose not to install additional binaries."
            return 1
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
header "dotfiles - https://github.com/xiaosq2000/dotfiles"

# Prompt for confirmation in interactive mode (unless skipped)
if [ "$INTERACTIVE" = true ] && [ "$SKIP_CONFIRMATION" = false ]; then
    confirm_installation
elif [ "$SKIP_CONFIRMATION" = true ]; then
    info "Skipping confirmation (--yes flag provided)"
fi

# Prompt for binary installation in interactive mode (if not specified)
if [ "$INTERACTIVE" = true ] && [ "$INSTALL_BINARIES" = false ]; then
    if confirm_binary_installation; then
        INSTALL_BINARIES=true
        info "Binary installation enabled via interactive prompt"
    else
        info "Binary installation skipped via interactive prompt"
    fi
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

    PIXI_SCRIPT="$HOME/.sh_utils/setup.d/pixi.sh"
    if [ -f "$PIXI_SCRIPT" ]; then
        info "running pixi installation script..."

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

    UV_SCRIPT="$HOME/.sh_utils/setup.d/uv.sh"
    if [ -f "$UV_SCRIPT" ]; then
        info "running uv installation script..."

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

    RUST_SCRIPT="$HOME/.sh_utils/setup.d/rust.sh"
    if [ -f "$RUST_SCRIPT" ]; then
        info "running rust installation script..."

        # Make script executable and run it
        chmod +x "$RUST_SCRIPT"
        if bash "$RUST_SCRIPT"; then
            success "rust installed successfully"
        else
            warning "rust installation encountered an error"
        fi
    else
        warning "rust setup script not found at $RUST_SCRIPT"
    fi

    NODEJS_SCRIPT="$HOME/.sh_utils/setup.d/node.sh"
    if [ -f "$NODEJS_SCRIPT" ]; then
        info "running Node.js installation script..."

        # Make script executable and run it
        chmod +x "$NODEJS_SCRIPT"
        if bash "$NODEJS_SCRIPT"; then
            success "Node.js (nvm, node, tree-sitter) installed successfully"
        else
            warning "Node.js installation encountered an error"
        fi
    else
        warning "Node.js setup script not found at $NODEJS_SCRIPT"
    fi

    ZSH_SCRIPT="$HOME/.sh_utils/setup.d/zsh.sh"
    if [ -f "$ZSH_SCRIPT" ]; then
        info "running zsh installation script..."

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

    GIT_SCRIPT="$HOME/.sh_utils/setup.d/git.sh"
    if [ -f "$GIT_SCRIPT" ]; then
        info "running Git tools installation script..."

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

    NEOVIM_SCRIPT="$HOME/.sh_utils/setup.d/neovim.sh"
    if [ -f "$NEOVIM_SCRIPT" ]; then
        info "running Neovim installation script..."

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

    FZF_SCRIPT="$HOME/.sh_utils/setup.d/fzf.sh"
    if [ -f "$FZF_SCRIPT" ]; then
        info "running fzf installation script..."

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

    YAZI_SCRIPT="$HOME/.sh_utils/setup.d/yazi.sh"
    if [ -f "$YAZI_SCRIPT" ]; then
        info "running yazi installation script..."

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

    AIDER_SCRIPT="$HOME/.sh_utils/setup.d/aider.sh"
    if [ -f "$AIDER_SCRIPT" ]; then
        info "running Aider installation script..."

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

    TYPEFACES_SCRIPT="$HOME/.sh_utils/setup.d/typefaces.sh"
    if [ -f "$TYPEFACES_SCRIPT" ]; then
        info "running typefaces installation script..."

        # Make script executable and run it
        chmod +x "$TYPEFACES_SCRIPT"
        if bash "$TYPEFACES_SCRIPT"; then
            success "typefaces (maple mono...) installed successfully"
        else
            warning "typefaces (maple mono...) installation encountered an error"
        fi
    else
        warning "typefaces setup script not found at $TYPEFACES_SCRIPT"
    fi
else
    if [ "$INTERACTIVE" != true ]; then
        info "skipping binary installation (use --with-binaries to install)"
    fi
fi

success "installation complete"
