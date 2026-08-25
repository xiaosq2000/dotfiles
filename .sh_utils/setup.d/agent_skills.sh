#!/usr/bin/env bash
set -eu

# Share one set of user-level agent skills across Claude Code, Codex and OpenCode.
#
# The canonical copies live in ~/.agents/skills/<name>/SKILL.md and are the only
# ones tracked in this dotfiles repo. This script points each agent at them:
#
#   Claude Code  ~/.claude/skills/<name>      symlink
#   Codex        ~/.codex/skills/<name>       symlink (respects $CODEX_HOME)
#   OpenCode     reads ~/.agents/skills natively, nothing to do
#
# The script is idempotent. Run it again after adding a skill, or after a fresh
# clone of the dotfiles. Use --prune to also drop links whose canonical skill is
# gone, and --dry-run to see what would change without touching anything.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UI_LIB="$SCRIPT_DIR/../lib/ui.sh"

if [ -f "$UI_LIB" ]; then
    # shellcheck disable=SC1090
    source "$UI_LIB"
else
    echo "error: UI library not found at $UI_LIB"
    exit 1
fi

SKILLS_ROOT="${AGENT_SKILLS_ROOT:-$HOME/.agents/skills}"
DRY_RUN=false
PRUNE=false

usage() {
    cat <<'EOF'
usage: agent_skills.sh [--prune] [--dry-run] [--help]

  --prune     remove links under an agent whose canonical skill no longer exists
  --dry-run   report what would change without writing anything
  --help      show this message

environment:
  AGENT_SKILLS_ROOT   canonical skills directory (default ~/.agents/skills)
  CODEX_HOME          Codex config directory (default ~/.codex)
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --prune) PRUNE=true ;;
        --dry-run|-n) DRY_RUN=true ;;
        --help|-h) usage; exit 0 ;;
        *) error "unknown option: $1"; usage; exit 2 ;;
    esac
    shift
done

header "agent skills - shared across Claude Code, Codex and OpenCode"

if [ ! -d "$SKILLS_ROOT" ]; then
    error "canonical skills directory not found at $SKILLS_ROOT"
    exit 1
fi

# Normalise so link targets and prune checks compare against one spelling.
SKILLS_ROOT="$(realpath -m "$SKILLS_ROOT" 2>/dev/null || printf '%s' "$SKILLS_ROOT")"

# Collect the canonical skill names: a directory holding a SKILL.md.
SKILLS=()
for candidate in "$SKILLS_ROOT"/*/; do
    [ -d "$candidate" ] || continue
    name="$(basename "$candidate")"
    if [ -f "$candidate/SKILL.md" ]; then
        SKILLS+=("$name")
    else
        warning "$name has no SKILL.md, skipping"
    fi
done

if [ ${#SKILLS[@]} -eq 0 ]; then
    warning "no skills found in $SKILLS_ROOT, nothing to do"
    footer "agent skills"
    exit 0
fi

info "canonical skills in $SKILLS_ROOT: ${SKILLS[*]}"

LINKED=0
UPDATED=0
SKIPPED=0
PRUNED=0
CONFLICTS=0

# Prefer a relative target so the links keep working under a different $HOME,
# for example a copied home directory or a container mount. Fall back to the
# absolute path when a relative one cannot be computed.
link_target() {
    local agent_dir="$1" name="$2"
    local absolute="$SKILLS_ROOT/$name"
    local relative
    if relative="$(realpath -m --relative-to="$agent_dir" "$absolute" 2>/dev/null)" \
        && [ -n "$relative" ]; then
        printf '%s' "$relative"
    else
        printf '%s' "$absolute"
    fi
}

link_skill() {
    local agent="$1" agent_dir="$2" name="$3"
    local link="$agent_dir/$name"
    local want
    want="$(link_target "$agent_dir" "$name")"

    if [ -L "$link" ]; then
        local have
        have="$(readlink "$link")"
        if [ "$have" = "$want" ]; then
            SKIPPED=$((SKIPPED + 1))
            debug "$agent/$name already linked"
            return
        fi
        if [ "$DRY_RUN" = true ]; then
            msg "  would relink $agent/$name ($have -> $want)"
        else
            ln -sfn "$want" "$link"
            step "relinked $agent/$name"
        fi
        UPDATED=$((UPDATED + 1))
        return
    fi

    if [ -e "$link" ]; then
        # A real file or directory is sitting where the link belongs. That is
        # almost always a hand copy made before the skills were centralised, so
        # say so instead of deleting someone's only copy.
        warning "$agent/$name is a real path, not a link; move or delete $link, then rerun"
        CONFLICTS=$((CONFLICTS + 1))
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        msg "  would link $agent/$name -> $want"
    else
        ln -s "$want" "$link"
        step "linked $agent/$name"
    fi
    LINKED=$((LINKED + 1))
}

prune_agent() {
    local agent="$1" agent_dir="$2"
    local link name resolved
    for link in "$agent_dir"/*; do
        [ -L "$link" ] || continue
        name="$(basename "$link")"
        # Only touch links that point into the canonical directory, so links an
        # agent or another tool made for itself are left alone.
        resolved="$(realpath -m "$link" 2>/dev/null)" || continue
        case "$resolved" in
            "$SKILLS_ROOT"/*) ;;
            *) continue ;;
        esac
        [ -e "$link" ] && continue
        if [ "$DRY_RUN" = true ]; then
            msg "  would prune dangling $agent/$name"
        else
            rm -f "$link"
            step "pruned dangling $agent/$name"
        fi
        PRUNED=$((PRUNED + 1))
    done
}

install_for_agent() {
    local agent="$1" agent_dir="$2"
    local name

    if [ "$DRY_RUN" = true ] && [ ! -d "$agent_dir" ]; then
        msg "  would create $agent_dir"
    else
        mkdir -p "$agent_dir"
    fi

    for name in "${SKILLS[@]}"; do
        link_skill "$agent" "$agent_dir" "$name"
    done

    if [ "$PRUNE" = true ]; then
        prune_agent "$agent" "$agent_dir"
    fi
}

# Claude Code reads ~/.claude/skills, or $CLAUDE_CONFIG_DIR/skills when set.
if command -v claude >/dev/null 2>&1; then
    install_for_agent "claude" "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills"
else
    info "claude not installed, skipping"
fi

# Codex reads $CODEX_HOME/skills. Its own bundled skills live in a .system
# subdirectory there and are left alone.
if command -v codex >/dev/null 2>&1; then
    install_for_agent "codex" "${CODEX_HOME:-$HOME/.codex}/skills"
else
    info "codex not installed, skipping"
fi

# OpenCode auto-loads ~/.claude/skills and ~/.agents/skills, so the canonical
# directory is already on its search path.
if command -v opencode >/dev/null 2>&1; then
    info "opencode reads $SKILLS_ROOT natively, no links needed"
else
    info "opencode not installed, skipping"
fi

msg ""
info "linked $LINKED, relinked $UPDATED, already correct $SKIPPED, pruned $PRUNED"

if [ "$CONFLICTS" -gt 0 ]; then
    warning "$CONFLICTS path(s) blocked by a real file or directory, see above"
    footer "agent skills"
    exit 1
fi

if [ "$DRY_RUN" = true ]; then
    hint "dry run, nothing was written"
else
    completed "all agents point at $SKILLS_ROOT"
fi

footer "agent skills"
