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
            echo "  --with-binaries     Install additional binaries (e.g., Neovim)"
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

# Source the UI library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/ui.sh"

# Function to prompt for confirmation
confirm_installation() {
    echo ""
    msg_warning "BACKUP FIRST! All your dotfiles will be REPLACED."
    echo ""
    msg_info "This will overwrite existing configuration files in your home directory."
    msg_info "Make sure you have backed up any important dotfiles before proceeding."
    echo ""

    read -p "Do you want to continue? (yes/no): " response

    case "$response" in
        [yY][eE][sS]|[yY])
            msg_success "Proceeding with installation..."
            return 0
            ;;
        *)
            msg_error "Installation cancelled."
            exit 0
            ;;
    esac
}

# Header
msg_header "DOTFILES INSTALLER - https://github.com/xiaosq2000/dotfiles"

# Prompt for confirmation in interactive mode (unless skipped)
if [ "$INTERACTIVE" = true ] && [ "$SKIP_CONFIRMATION" = false ]; then
    confirm_installation
elif [ "$SKIP_CONFIRMATION" = true ]; then
    msg_info "Skipping confirmation (--yes flag provided)"
fi

# Change to home directory
msg_step "Changing to home directory"
cd ~
msg_success "Changed to home directory: $(pwd)"

# Initialize git repository
msg_step "Initializing git repository in home directory"
git init >/dev/null 2>&1 &
pid=$!
spinner $pid
msg_success "Git repository initialized"

# Add remote origin
msg_step "Adding remote origin"
git remote add origin https://github.com/xiaosq2000/dotfiles >/dev/null 2>&1 &
pid=$!
spinner $pid
msg_success "Remote origin added"

# Fetch all branches
msg_step "Fetching all branches (this may take a moment)"
git fetch --all >/dev/null 2>&1 &
pid=$!
spinner $pid
msg_success "All branches fetched"

# Reset to match origin/main
msg_step "Resetting to origin/main"
git reset --hard origin/main >/dev/null 2>&1 &
pid=$!
spinner $pid
msg_success "Reset to origin/main complete"

# Rename branch to main
msg_step "Renaming branch to main"
git branch -M main >/dev/null 2>&1 &
pid=$!
spinner $pid
msg_success "Branch renamed to main"

# Set upstream branch
msg_step "Setting upstream branch"
git branch -u origin/main main >/dev/null 2>&1 &
pid=$!
spinner $pid
msg_success "Upstream branch set"

# Initialize all submodules
msg_step "Initializing git submodules (optional)"
if git submodule update --init ~/.config/themes/rose-pine/starship >/dev/null 2>&1; then
    msg_success "starship's rose-pine theme initialized"
else
    msg_warning "Skipping submodule initialization due to an error (continuing)"
fi

# Install binaries if requested
if [ "$INSTALL_BINARIES" = true ]; then
    msg_step "Installing additional binaries"

    # Check if neovim setup script exists
    NEOVIM_SCRIPT="$HOME/.sh_utils/setup.d/neovim.sh"
    if [ -f "$NEOVIM_SCRIPT" ]; then
        msg_info "Running Neovim installation script..."

        # Make script executable and run it
        chmod +x "$NEOVIM_SCRIPT"
        if bash "$NEOVIM_SCRIPT"; then
            msg_success "Neovim installed successfully"
        else
            msg_warning "Neovim installation encountered an error"
        fi
    else
        msg_warning "Neovim setup script not found at $NEOVIM_SCRIPT"
    fi
else
    msg_info "Skipping binary installation (use --with-binaries to install)"
fi

# Footer
msg_footer "INSTALLATION COMPLETE!"
msg_success "Your dotfiles have been successfully installed!"
