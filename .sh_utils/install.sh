#!/bin/bash

# Script to install dotfiles from https://github.com/xiaosq2000/dotfiles
# Created on February 27, 2025
#
# CAUTION: Backup first! All your dotfiles will be REPLACED.

set -e # Exit immediately if a command exits with a non-zero status

# Colors and formatting
BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
NC="\033[0m" # No Color
CHECK_MARK="${GREEN}✓${NC}"
ARROW="${BLUE}→${NC}"

# Function for displaying step information
step() {
	echo -e "\n${ARROW} ${BOLD}$1${NC}"
}

# Function for displaying success messages
success() {
	echo -e "${CHECK_MARK} ${GREEN}$1${NC}"
}

# Function to show a simple spinner
spinner() {
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
}

# Header
clear
echo -e "${BOLD}${BLUE}"
echo '╔════════════════════════════════════════════════════════════╗'
echo '║                   DOTFILES INSTALLER                       ║'
echo '║              https://github.com/xiaosq2000                 ║'
echo '╚════════════════════════════════════════════════════════════╝'
echo -e "${NC}"

# Change to home directory
step "Changing to home directory"
cd ~
success "Changed to home directory: $(pwd)"

# Initialize git repository
step "Initializing git repository in home directory"
git init >/dev/null 2>&1 &
spinner $!
success "Git repository initialized"

# Add remote origin
step "Adding remote origin"
git remote add origin https://github.com/xiaosq2000/dotfiles >/dev/null 2>&1 &
spinner $!
success "Remote origin added"

# Fetch all branches
step "Fetching all branches (this may take a moment)"
git fetch --all >/dev/null 2>&1 &
spinner $!
success "All branches fetched"

# Reset to match origin/main
step "Resetting to origin/main"
git reset --hard origin/main >/dev/null 2>&1 &
spinner $!
success "Reset to origin/main complete"

# Rename branch to main
step "Renaming branch to main"
git branch -M main >/dev/null 2>&1 &
spinner $!
success "Branch renamed to main"

# Set upstream branch
step "Setting upstream branch"
git branch -u origin/main main >/dev/null 2>&1 &
spinner $!
success "Upstream branch set"

# Footer
echo -e "\n${BOLD}${GREEN}"
echo '╔════════════════════════════════════════════════════════════╗'
echo '║                 INSTALLATION COMPLETE!                     ║'
echo '╚════════════════════════════════════════════════════════════╝'
echo -e "${NC}"
echo -e "Your dotfiles have been successfully installed!"
