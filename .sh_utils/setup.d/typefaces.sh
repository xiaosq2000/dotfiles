#!/usr/bin/env bash
set -euo pipefail

# Typeface installer (tuple-driven):
# - Supports multiple typefaces (GitHub release or direct URL)
# - Flattens archives and installs only desired font extensions (ttf/otf)
# - Skips if already at recorded ref (tag or version)
# - Refreshes font cache once after all installs

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load UI library for consistent CLI output
UI_LIB="${UI_LIB:-$SCRIPT_DIR/../lib/ui.sh}"
if [ -f "$UI_LIB" ]; then
    # shellcheck source=../lib/ui.sh
    source "$UI_LIB"
else
    echo "error: $UI_LIB not found"
    exit 1
fi

FONTS_BASE="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"

ensure_deps() {
    local missing=()
    for cmd in curl unzip fc-cache sed mktemp find; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing required commands: ${missing[*]}"
        exit 1
    fi
}

# Resolve the latest GitHub release tag for a repo ("owner/name")
github_latest_tag() {
    local repo="${1:?repo is required (owner/name)}"
    curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
        | sed -nE 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' \
        | head -n1
}

# Load a typeface tuple into shell variables for a given id.
# Exposes: id name exts source [repo tag asset] or [url version] install_dir
load_spec() {
    local req_id="${1:?id is required}"

    # shellcheck disable=SC2034  # variables intentionally exported to caller
    case "$req_id" in
        "MapleMono-NF-CN-unhinted")
            id="MapleMono-NF-CN-unhinted"
            name="Maple Mono (NF CN unhinted)"
            exts="ttf"
            source="github"
            repo="subframe7536/maple-font"
            tag="latest" # will resolve via GitHub API
            asset="MapleMono-NF-CN-unhinted.zip"
            install_dir="$FONTS_BASE/$id"
            ;;
        "tex-gyre-adventor")
            id="tex-gyre-adventor"
            name="TeX Gyre Adventor"
            exts="otf"
            source="url"
            url="https://www.gust.org.pl/projects/e-foundry/tex-gyre/adventor/qag2_501otf.zip"
            version="2.501"
            install_dir="$FONTS_BASE/$id"
            ;;
        "source-han-sans-sc")
            id="source-han-sans-sc"
            name="Source Han Sans (SC)"
            exts="otf"
            source="github"
            repo="adobe-fonts/source-han-sans"
            tag="latest" # will resolve via GitHub API
            asset="09_SourceHanSansSC.zip"
            install_dir="$FONTS_BASE/$id"
            ;;
        *)
            error "unknown typeface id: $req_id"
            return 1
            ;;
    esac
}

fonts_present() {
    local dir="${1:?dir required}"; shift || true
    local exts="${*:-}"
    for ext in $exts; do
        if compgen -G "$dir/*.$ext" >/dev/null; then
            return 0
        fi
    done
    return 1
}

install_typeface() {
    local id="${1:?id required}"

    # Populate spec variables
    load_spec "$id"

    # shellcheck disable=SC2154  # set by load_spec
    local dest="${install_dir:-$FONTS_BASE/$id}"
    mkdir -p "$dest"

    local ref download_url
    # shellcheck disable=SC2154  # set by load_spec
    if [ "${source}" = "github" ]; then
        # shellcheck disable=SC2154
        if [ "${tag}" = "latest" ]; then
            ref="$(github_latest_tag "${repo}")"
            if [ -z "${ref:-}" ]; then
                error "unable to resolve latest tag for ${name} (${repo})"
                return 1
            fi
        else
            ref="${tag}"
        fi
        # shellcheck disable=SC2154
        download_url="https://github.com/${repo}/releases/download/${ref}/${asset}"
    elif [ "${source}" = "url" ]; then
        # shellcheck disable=SC2154
        ref="${version:?version required for source=url}"
        # shellcheck disable=SC2154
        download_url="${url:?url required for source=url}"
    else
        error "unsupported source '${source}' for ${name}"
        return 1
    fi

    local ref_file="$dest/.installed-ref"
    # shellcheck disable=SC2154
    if [ -f "$ref_file" ] && [ "$(cat "$ref_file")" = "$ref" ] && fonts_present "$dest" "$exts"; then
        success "${name} is already at latest (${ref})"
        return 0
    fi

    step "installing ${name}"
    info "ref: ${ref}"

    local tmpd="$TMP_ROOT/$id"
    mkdir -p "$tmpd/extract"

    local filename
    filename="$(basename "$download_url")"

    step "downloading ${filename}"
    curl -fsSLo "$tmpd/$filename" "$download_url"

    step "extracting ${filename}"
    unzip -o -q "$tmpd/$filename" -d "$tmpd/extract"

    # Copy only the allowed font extensions, flattened into dest
    local copied=0
    # shellcheck disable=SC2154
    for ext in $exts; do
        while IFS= read -r -d '' f; do
            cp -f "$f" "$dest/"
            copied=1
        done < <(find "$tmpd/extract" -type f -iname "*.${ext}" -print0)
    done

    if [ "$copied" -eq 0 ]; then
        error "no .ttf/.otf files found for ${name} after extraction"
        return 1
    fi

    printf '%s\n' "$ref" >"$ref_file"
    success "installed ${name} (${ref}) into ${dest}"
}

main() {
    header "typefaces installation"
    mkdir -p "$FONTS_BASE"
    ensure_deps

    # Create a single temp root to reuse and clean at exit
    TMP_ROOT="$(mktemp -d)"
    export TMP_ROOT
    trap 'rm -rf "$TMP_ROOT"' EXIT

    # Registry of typeface ids to install
    local FONT_IDS=(
        "MapleMono-NF-CN-unhinted"
        "tex-gyre-adventor"
        "source-han-sans-sc"
    )

    for font_id in "${FONT_IDS[@]}"; do
        install_typeface "$font_id"
    done

    step "refreshing font cache"
    fc-cache -f "$FONTS_BASE" >/dev/null 2>&1 || true

    footer "typefaces installation"
}

main "$@"
