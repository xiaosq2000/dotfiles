#!/usr/bin/env bash
# Assert that every setup script the chezmoi run script names actually exists.
#
# install.sh pointed at a nonexistent setup.d/node.sh for a long time without
# anyone noticing, because a missing script only produced a warning and the run
# still reported success. The orchestrator now treats that as an error, but the
# error only surfaces on a machine that actually applies. This check is the
# cheap guard: it compares the names in the run script against the source tree,
# so a typo fails in CI in a second rather than silently skipping a tool.
#
# The ordered list used to live in .sh_utils/install.sh, which chezmoi replaced.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

RUN_SCRIPT="run_onchange_after_10-setup-tools.sh.tmpl"
SETUP_DIR="dot_sh_utils/setup.d"
status=0

[ -f "$RUN_SCRIPT" ] || {
    echo "error: $RUN_SCRIPT not found; has it been renamed?" >&2
    exit 1
}

# The list is a Go template expression:
#   {{ $setup := list "pixi" "uv" ... -}}
# Pull the quoted names out of that one line, then add any name passed to
# run_setup directly, skipping shell variables like "$name".
names=$(
    {
        sed -n 's/.*\$setup := list \(.*\)-}}.*/\1/p' "$RUN_SCRIPT" | grep -o '"[^"]*"' | tr -d '"'
        sed -n 's/^[[:space:]]*run_setup "\([^"$]*\)".*/\1/p' "$RUN_SCRIPT"
    } | sort -u
)

# agent_skills.sh is invoked from its own run script rather than the list.
names=$(printf '%s\nagent_skills\n' "$names" | sort -u)

if [ -z "$names" ]; then
    echo "error: no setup script names found in $RUN_SCRIPT; has its format changed?" >&2
    exit 1
fi

while IFS= read -r name; do
    [ -n "$name" ] || continue
    # setup.d scripts are executable, so chezmoi stores them with that prefix.
    script="$SETUP_DIR/executable_${name}.sh"
    if [ -f "$script" ]; then
        printf 'ok       %s\n' "$script"
    else
        printf 'MISSING  %s (referenced by %s)\n' "$script" "$RUN_SCRIPT" >&2
        status=1
    fi
done <<<"$names"

if [ "$status" -ne 0 ]; then
    echo >&2
    echo "error: the run script references setup scripts that do not exist" >&2
fi

exit "$status"
