#!/usr/bin/env bash

# Platform detection utilities (GOOS/GOARCH with hyphen separator)
# Supported: linux-amd64, linux-arm64, darwin-amd64, darwin-arm64

plat_os() {
    case "$(uname -s 2>/dev/null || echo unknown)" in
        Linux) echo linux ;;
        Darwin) echo darwin ;;
        *) echo unknown ;;
    esac
}

# Title-cased OS token for GitHub release assets (e.g., Linux, Darwin)
plat_os_title() {
    case "$(plat_os)" in
        linux) echo Linux ;;
        darwin) echo Darwin ;;
        *) echo ;;
    esac
}

plat_arch() {
    case "$(uname -m 2>/dev/null || echo unknown)" in
        x86_64|amd64) echo amd64 ;;
        arm64|aarch64) echo arm64 ;;
        *) echo unknown ;;
    esac
}

# Returns "os-arch" (e.g., linux-amd64)
plat_id() {
    printf "%s-%s\n" "$(plat_os)" "$(plat_arch)"
}

# Returns "os{sep}arch" with custom separator (default "_")
plat_id_sep() {
    local sep="${1:-_}"
    printf "%s%s%s\n" "$(plat_os)" "$sep" "$(plat_arch)"
}

# Rust target triple for difftastic
plat_rust_triple() {
    case "$(plat_id)" in
        linux-amd64) echo x86_64-unknown-linux-gnu ;;
        linux-arm64) echo aarch64-unknown-linux-gnu ;;
        darwin-amd64) echo x86_64-apple-darwin ;;
        darwin-arm64) echo aarch64-apple-darwin ;;
        *) echo ;;
    esac
}

# Arch aliases for project-specific asset naming
# Usage: plat_arch_alias lazygit
plat_arch_alias() {
    local style="${1:-}"
    case "$style:$(plat_arch)" in
        lazygit:amd64) echo x86_64 ;;
        lazygit:arm64) echo arm64 ;;
        lazydocker:amd64) echo x86_64 ;;
        lazydocker:arm64) echo arm64 ;;
        *) echo ;;
    esac
}
