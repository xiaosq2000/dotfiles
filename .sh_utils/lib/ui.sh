#!/bin/bash

# Simple UI library for consistent CLI output across scripts
# Automatically detects interactive vs headless environments

# Detect if we're in an interactive environment
if [ -t 1 ] && [ -z "${DOCKER_CONTAINER:-}" ]; then
    INTERACTIVE=true
    # Colors for interactive mode
    BOLD="\033[1m"
    GREEN="\033[0;32m"
    BLUE="\033[0;34m"
    YELLOW="\033[0;33m"
    RED="\033[0;31m"
    NC="\033[0m"
else
    INTERACTIVE=false
    # No colors for headless mode
    BOLD=""
    GREEN=""
    BLUE=""
    YELLOW=""
    RED=""
    NC=""
fi

# Display a step/action being performed
msg_step() {
    if [ "$INTERACTIVE" = true ]; then
        echo -e "\n${BLUE}→${NC} ${BOLD}$1${NC}"
    else
        echo "STEP: $1"
    fi
}

# Display a success message
msg_success() {
    if [ "$INTERACTIVE" = true ]; then
        echo -e "${GREEN}✓${NC} $1"
    else
        echo "DONE: $1"
    fi
}

# Display an error message
msg_error() {
    if [ "$INTERACTIVE" = true ]; then
        echo -e "${RED}✗${NC} ${RED}$1${NC}" >&2
    else
        echo "ERROR: $1" >&2
    fi
}

# Display a warning message
msg_warning() {
    if [ "$INTERACTIVE" = true ]; then
        echo -e "${YELLOW}⚠${NC}  ${YELLOW}$1${NC}"
    else
        echo "WARNING: $1"
    fi
}

# Display an info message
msg_info() {
    if [ "$INTERACTIVE" = true ]; then
        echo -e "${BLUE}ℹ${NC}  $1"
    else
        echo "INFO: $1"
    fi
}

# Simple spinner for long-running operations
spinner() {
    if [ "$INTERACTIVE" = true ]; then
        local pid=$1
        local delay=0.1
        local spinstr='|/-\'
        while kill -0 $pid 2>/dev/null; do
            local temp=${spinstr#?}
            printf " [%c]  " "$spinstr"
            local spinstr=$temp${spinstr%"$temp"}
            sleep $delay
            printf "\b\b\b\b\b\b"
        done
        printf "    \b\b\b\b"
    else
        # In headless mode, just wait
        wait $1 2>/dev/null || true
    fi
}

# Display a header (for main scripts)
msg_header() {
    if [ "$INTERACTIVE" = true ]; then
        echo -e "\n${BOLD}${BLUE}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${BOLD}${BLUE}  $1${NC}"
        echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
    else
        echo "========================================"
        echo "  $1"
        echo "========================================"
    fi
}

# Display a footer (for main scripts)
msg_footer() {
    if [ "$INTERACTIVE" = true ]; then
        echo -e "\n${BOLD}${GREEN}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${BOLD}${GREEN}  $1${NC}"
        echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════${NC}\n"
    else
        echo "========================================"
        echo "  $1"
        echo "========================================"
    fi
}
