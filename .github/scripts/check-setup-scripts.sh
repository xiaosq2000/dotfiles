#!/usr/bin/env bash
# Assert that every setup script the chezmoi run scripts name actually exists.
#
# install.sh pointed at a nonexistent setup.d/node.sh for a long time without
# anyone noticing, because a missing script only produced a warning and the run
# still reported success. The orchestrator now treats that as an error, but the
# error only surfaces on a machine that actually applies. This check is the
# cheap guard: it compares the names in the run scripts against the source tree,
# so a typo fails in CI in a second rather than silently skipping a tool.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

SETUP_DIR="dot_sh_utils/setup.d"
status=0

shopt -s nullglob
RUN_SCRIPTS=(run_onchange_after_*.sh.tmpl)
shopt -u nullglob

[ ${#RUN_SCRIPTS[@]} -gt 0 ] || {
    echo "error: no run_onchange_after_*.sh.tmpl found; have they been renamed?" >&2
    exit 1
}

# Names appear in four shapes across the run scripts:
#   the base list      {{ $setup := list "zsh" "nodejs" -}}
#   a conditional add  {{ if $m.rust }}{{ $setup = append $setup "rust" }}{{ end }}
#   a direct call      run_setup "typefaces"
#   an exec'd path     exec "$HOME/.sh_utils/setup.d/pixi.sh"
# The conditional shape matters: a name only reachable on some machines is
# exactly the one a typo hides, because the machines that would notice are the
# ones nobody applies to first.
# Drop anything holding a shell expansion, which is the loop's own
# run_setup "$name" line.
names=$(
    {
        grep -h 'setup := list' "${RUN_SCRIPTS[@]}" | grep -o '"[^"]*"' | tr -d '"'
        grep -ho 'append \$setup "[^"$]*"' "${RUN_SCRIPTS[@]}" |
            sed 's/append \$setup "//; s/"$//'
        grep -ho 'run_setup "[^"$]*"' "${RUN_SCRIPTS[@]}" | sed 's/run_setup "//; s/"$//'
        grep -ho '\.sh_utils/setup\.d/[A-Za-z0-9_-]*\.sh' "${RUN_SCRIPTS[@]}" |
            sed 's|.*/||; s|\.sh$||'
    } | grep -v '\$' | sort -u
)

if [ -z "$names" ]; then
    echo "error: no setup script names found in ${RUN_SCRIPTS[*]}" >&2
    exit 1
fi

while IFS= read -r name; do
    [ -n "$name" ] || continue
    # setup.d scripts are executable, so chezmoi stores them with that prefix.
    script="$SETUP_DIR/executable_${name}.sh"
    if [ -f "$script" ]; then
        printf 'ok       %s\n' "$script"
    else
        printf 'MISSING  %s (referenced by a run_onchange script)\n' "$script" >&2
        status=1
    fi
done <<<"$names"

if [ "$status" -ne 0 ]; then
    echo >&2
    echo "error: a run script references setup scripts that do not exist" >&2
fi

exit "$status"
