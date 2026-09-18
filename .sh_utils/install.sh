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
INSTALL_TYPEFACES=false
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
        --with-typefaces)
            INSTALL_TYPEFACES=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -y, --yes           Skip confirmation prompt and proceed with installation"
            echo "  --with-binaries     Install additional binaries (will prompt in interactive mode if not specified)"
            echo "  --with-typefaces    Install typefaces"
            echo "  -h, --help          Show this help message"
            echo ""
            echo "When using with curl, pass arguments like this:"
            echo "  curl -fsSL \"URL\" | bash -s -- [OPTIONS]"
            echo ""
            echo "Examples:"
            echo "  curl -fsSL \"URL\" | bash -s -- -y"
            echo "  curl -fsSL \"URL\" | bash -s -- -y --with-binaries"
            echo "  curl -fsSL \"URL\" | bash -s -- -y --with-typefaces"
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
    info "Optional: Install additional developer binaries (Neovim, Git tools, Node.js, Rust, uv, pixi, fzf, yazi, zsh)."
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

# Function to prompt for typefaces
confirm_typefaces_installation() {
    echo ""
    info "Optional: Install typefaces (e.g., Maple Mono and others)."
    echo ""
    read -p "Do you want to install typefaces? (yes/no): " response
    case "$response" in
        [yY][eE][sS]|[yY])
            success "Will install typefaces..."
            return 0
            ;;
        *)
            info "You chose not to install typefaces."
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

# Prompt for typefaces installation in interactive mode (if not specified)
if [ "$INTERACTIVE" = true ] && [ "$INSTALL_TYPEFACES" = false ]; then
    if confirm_typefaces_installation; then
        INSTALL_TYPEFACES=true
        info "Typeface installation enabled via interactive prompt"
    else
        info "Typeface installation skipped via interactive prompt"
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

# Names of setup scripts that did not complete, reported together at the end.
SETUP_FAILED=""

# Run one installer from .sh_utils/setup.d.
#
# A script that is missing is an error rather than a warning. Every name passed
# here is meant to resolve, so one that does not is a bug in this file, not a
# condition to tolerate: a warning let install.sh point at a nonexistent
# node.sh through many releases while still reporting overall success.
run_setup() {
    local name="$1" label="$2"
    local script="$HOME/.sh_utils/setup.d/${name}.sh"

    if [ ! -f "$script" ]; then
        error "setup script not found at $script"
        SETUP_FAILED="$SETUP_FAILED $name"
        return 1
    fi

    info "running $label installation script..."
    chmod +x "$script"
    if bash "$script"; then
        success "$label installed successfully"
        return 0
    fi

    warning "$label installation encountered an error"
    SETUP_FAILED="$SETUP_FAILED $name"
    return 1
}

# Order matters: pixi and uv put tools on PATH that the later scripts expect.
SETUP_SCRIPTS=(
    "pixi:pixi"
    "uv:uv"
    "rust:rust"
    "nodejs:Node.js (pnpm and the latest LTS node)"
    "zsh:zsh (oh-my-zsh and plugins)"
    "neovim:Neovim"
    "fzf:fzf"
    "yazi:yazi"
    "lazydocker:lazydocker"
)

# Install binaries if requested
if [ "$INSTALL_BINARIES" = true ]; then
    step "Installing additional binaries"

    for entry in "${SETUP_SCRIPTS[@]}"; do
        # Keep going after a failure so one broken installer does not hide the
        # state of the rest; SETUP_FAILED carries the verdict to the end.
        run_setup "${entry%%:*}" "${entry#*:}" || true
    done
else
    if [ "$INTERACTIVE" != true ] && [ "$INSTALL_TYPEFACES" = false ]; then
        info "skipping binary installation (use --with-binaries to install)"
    fi
fi

# Install typefaces if requested
if [ "$INSTALL_TYPEFACES" = true ]; then
    step "Installing typefaces"
    run_setup "typefaces" "typefaces (maple mono...)" || true
fi

# Point every installed AI agent at the shared skills in ~/.agents/skills. Cheap
# and safe to run even when no agent is installed, so it is not gated behind a
# flag.
step "Linking shared agent skills"
run_setup "agent_skills" "shared agent skills" || true

if [ -n "$SETUP_FAILED" ]; then
    error "these setup scripts did not complete:$SETUP_FAILED"
    exit 1
fi

success "installation complete"
