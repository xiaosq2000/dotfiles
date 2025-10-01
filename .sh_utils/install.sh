#!/bin/bash

# Script to install dotfiles from https://github.com/xiaosq2000/dotfiles
# Modified to work in both interactive and headless environments

set -e # Exit immediately if a command exits with a non-zero status

# Detect if we're in an interactive environment
if [ -t 1 ] && [ -z "$DOCKER_CONTAINER" ]; then
    # We're in an interactive terminal and not in a Docker container
    INTERACTIVE=true
else
    # We're in a non-interactive or Docker environment
    INTERACTIVE=false
fi

# Colors and formatting (only used in interactive mode)
if [ "$INTERACTIVE" = true ]; then
    BOLD="\033[1m"
    GREEN="\033[0;32m"
    BLUE="\033[0;34m"
    YELLOW="\033[0;33m"
    RED="\033[0;31m"
    NC="\033[0m" # No Color
    CHECK_MARK="${GREEN}✓${NC}"
    ARROW="${BLUE}→${NC}"
else
    BOLD=""
    GREEN=""
    BLUE=""
    YELLOW=""
    RED=""
    NC=""
    CHECK_MARK="✓"
    ARROW=">"
fi

# Function for displaying step information
step() {
    if [ "$INTERACTIVE" = true ]; then
        echo -e "\n${ARROW} ${BOLD}$1${NC}"
    else
        echo "$1"
    fi
}

# Function for displaying success messages
success() {
    if [ "$INTERACTIVE" = true ]; then
        echo -e "${CHECK_MARK} ${GREEN}$1${NC}"
    else
        echo "DONE: $1"
    fi
}

# Function to show a simple spinner
spinner() {
    if [ "$INTERACTIVE" = true ]; then
        local pid=$1
        local delay=0.1
        local spinstr='|/-\'
        while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
            local temp=${spinstr#?}
            printf " [%c]  " "$spinstr"
            local spinstr=$temp${spinstr%"$temp"}
            sleep $delay
            printf "\b\b\b\b\b\b"
        done
        printf "    \b\b\b\b"
    else
        # In non-interactive mode, just wait for the process
        wait $1
    fi
}

# Function to prompt for confirmation
confirm_installation() {
    echo -e "\n${BOLD}${RED}⚠️  WARNING: Backup first! All your dotfiles will be REPLACED.${NC}\n"
    echo -e "${YELLOW}This will overwrite existing configuration files in your home directory.${NC}"
    echo -e "${YELLOW}Make sure you have backed up any important dotfiles before proceeding.${NC}\n"

    read -p "Do you want to continue? (yes/no): " response

    case "$response" in
        [yY][eE][sS]|[yY])
            echo -e "\n${GREEN}Proceeding with installation...${NC}"
            return 0
            ;;
        *)
            echo -e "\n${RED}Installation cancelled.${NC}"
            exit 0
            ;;
    esac
}

# Header
if [ "$INTERACTIVE" = true ]; then
    clear
    echo -e "${BOLD}${BLUE}"
    echo '╔════════════════════════════════════════════════════════════╗'
    echo '║                   DOTFILES INSTALLER                       ║'
    echo '║              https://github.com/xiaosq2000                 ║'
    echo '╚════════════════════════════════════════════════════════════╝'
    echo -e "${NC}"
else
    echo "DOTFILES INSTALLER (https://github.com/xiaosq2000)"
fi

# Prompt for confirmation in interactive mode
if [ "$INTERACTIVE" = true ]; then
    confirm_installation
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
    if [ "$INTERACTIVE" = true ]; then
        echo -e "${YELLOW}Skipping submodule initialization due to an error (continuing).${NC}"
    else
        echo "SKIP: Submodule initialization failed; continuing."
    fi
fi

# Footer
if [ "$INTERACTIVE" = true ]; then
    echo -e "\n${BOLD}${GREEN}"
    echo '╔════════════════════════════════════════════════════════════╗'
    echo '║                 INSTALLATION COMPLETE!                     ║'
    echo '╚════════════════════════════════════════════════════════════╝'
    echo -e "${NC}"
    echo -e "Your dotfiles have been successfully installed!"
else
    echo "INSTALLATION COMPLETE! Your dotfiles have been successfully installed."
fi
