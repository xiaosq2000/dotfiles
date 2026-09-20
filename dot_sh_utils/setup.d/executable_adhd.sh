#!/usr/bin/env bash
set -eu

# Install the i-have-adhd skill for whichever agents are on this machine.
#
# The skill reshapes agent output to be acted on rather than read: the next
# action first, numbered steps, no preamble. Upstream ships it as a plugin with
# a marketplace behind it, one per agent:
#
#   Claude Code  claude plugin marketplace add / plugin install
#   Codex        codex plugin marketplace add / plugin add
#
# Not a shared skill under ~/.agents/skills, which is where every other skill in
# this repository lives. Vendoring a copy would mean hand-syncing it against an
# upstream that is still moving, and the plugin brings hooks a plain SKILL.md
# cannot. The cost is that this is imperative state per machine, which is what
# this script is for.
#
# Installing changes nothing on its own. The skill is opt-in on both agents
# (`disable-model-invocation: true` for Claude Code, `allow_implicit_invocation:
# false` for Codex), so neither model can reach for it unasked. Turning it on is
# `/i-have-adhd` in Claude Code or `$i-have-adhd` in Codex, per session, and
# "stop adhd mode" to end it.
#
# Idempotent, and cheap when there is nothing to do: an already-installed agent
# costs one grep, not a network round trip. Both upstream CLIs are idempotent
# too, so a re-run after a partial install finishes the job.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UI_LIB="$SCRIPT_DIR/../lib/ui.sh"

if [ -f "$UI_LIB" ]; then
    # shellcheck disable=SC1090
    source "$UI_LIB"
else
    echo "error: UI library not found at $UI_LIB"
    exit 1
fi

REPO="ayghri/i-have-adhd"
PLUGIN="i-have-adhd@i-have-adhd"

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"

DRY_RUN=false
UPDATE=false

usage() {
    cat <<'EOF'
usage: adhd.sh [--update] [--dry-run] [--help]

  --update    refresh the marketplace and reinstall, picking up upstream changes
  --dry-run   report what would change without writing anything
  --help      show this message

environment:
  CLAUDE_CONFIG_DIR   Claude Code config directory (default ~/.claude)
  CODEX_HOME          Codex config directory (default ~/.codex)
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --update) UPDATE=true ;;
        --dry-run | -n) DRY_RUN=true ;;
        --help | -h)
            usage
            exit 0
            ;;
        *)
            error "unknown option: $1"
            usage
            exit 2
            ;;
    esac
    shift
done

header "i-have-adhd - Claude Code and Codex"

INSTALLED=0
SKIPPED=0
FAILED=0

# Each agent records an installed plugin in a file of its own, so "is it already
# there" is a grep rather than shelling out to the CLI, which on Codex means
# listing every marketplace it knows about.
claude_has_plugin() {
    grep -qF "\"$PLUGIN\"" "$CLAUDE_DIR/plugins/installed_plugins.json" 2>/dev/null
}

codex_has_plugin() {
    grep -qF "[plugins.\"$PLUGIN\"]" "$CODEX_DIR/config.toml" 2>/dev/null
}

# Runs a step unless this is a dry run, and folds the failure into a count
# instead of aborting: one agent failing to install should not stop the other,
# and a network hiccup on a login node should not fail `chezmoi apply`.
attempt() {
    local what="$1"
    shift
    if [ "$DRY_RUN" = true ]; then
        msg "  would run: $*"
        return 0
    fi
    if "$@" >/dev/null 2>&1; then
        return 0
    fi
    warning "$what failed: $*"
    return 1
}

install_claude() {
    if [ "$UPDATE" = false ] && claude_has_plugin; then
        SKIPPED=$((SKIPPED + 1))
        debug "claude already has $PLUGIN"
        return 0
    fi

    if [ "$UPDATE" = true ] && claude_has_plugin; then
        attempt "claude marketplace update" \
            claude plugin marketplace update i-have-adhd || true
    fi

    if attempt "claude marketplace add" claude plugin marketplace add "$REPO" \
        && attempt "claude plugin install" claude plugin install "$PLUGIN"; then
        INSTALLED=$((INSTALLED + 1))
        step "claude: $PLUGIN"
    else
        FAILED=$((FAILED + 1))
    fi
}

install_codex() {
    if [ "$UPDATE" = false ] && codex_has_plugin; then
        SKIPPED=$((SKIPPED + 1))
        debug "codex already has $PLUGIN"
        return 0
    fi

    if [ "$UPDATE" = true ] && codex_has_plugin; then
        attempt "codex marketplace upgrade" \
            codex plugin marketplace upgrade i-have-adhd || true
    fi

    # --ref main because Codex pins a marketplace to a ref and defaults to the
    # repository's default branch only when told which one that is.
    if attempt "codex marketplace add" codex plugin marketplace add "$REPO" --ref main \
        && attempt "codex plugin add" codex plugin add "$PLUGIN"; then
        INSTALLED=$((INSTALLED + 1))
        step "codex: $PLUGIN"
    else
        FAILED=$((FAILED + 1))
    fi
}

if command -v claude >/dev/null 2>&1; then
    install_claude
else
    info "claude not installed, skipping"
fi

if command -v codex >/dev/null 2>&1; then
    install_codex
else
    info "codex not installed, skipping"
fi

msg ""
info "installed $INSTALLED, already present $SKIPPED, failed $FAILED"

if [ "$FAILED" -gt 0 ]; then
    warning "$FAILED agent(s) did not install, see above"
    hint "rerun with ~/.sh_utils/setup.d/adhd.sh once the network is back"
    footer "i-have-adhd"
    exit 1
fi

if [ "$DRY_RUN" = true ]; then
    hint "dry run, nothing was written"
else
    # Installing is a property of the machine and belongs in this repository.
    # Whether a given conversation wants the skill is a decision per session,
    # and the agent already has a way to say so.
    hint "opt-in: \`/i-have-adhd\` in Claude Code, \`\$i-have-adhd\` in Codex"
fi

footer "i-have-adhd"
