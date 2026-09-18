#!/usr/bin/env bash
# Assert that every setup script install.sh names actually exists.
#
# install.sh pointed at a nonexistent setup.d/node.sh for a long time without
# anyone noticing, because a missing script only produced a warning and the run
# still reported success. install.sh now treats that as an error, but the error
# only surfaces on a machine that actually runs the installer. This check is the
# cheap guard: it compares the names install.sh uses against setup.d, so a typo
# fails in CI in a second rather than silently skipping a tool on a new machine.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

INSTALL_SH=".sh_utils/install.sh"
SETUP_DIR=".sh_utils/setup.d"
status=0

# Names come from two places: the SETUP_SCRIPTS array, and the standalone
# run_setup calls for typefaces and agent skills. Drop any name holding a shell
# expansion, which is the loop's own `run_setup "${entry%%:*}"` line.
names=$(
    {
        sed -n '/^SETUP_SCRIPTS=(/,/^)/p' "$INSTALL_SH" |
            sed -n 's/^[[:space:]]*"\([^":]*\):.*/\1/p'
        sed -n 's/^[[:space:]]*run_setup "\([^"]*\)".*/\1/p' "$INSTALL_SH"
    } | grep -v '\$' | sort -u
)

if [ -z "$names" ]; then
    echo "error: no setup script names found in $INSTALL_SH; has its format changed?" >&2
    exit 1
fi

while IFS= read -r name; do
    script="$SETUP_DIR/${name}.sh"
    if [ -f "$script" ]; then
        printf 'ok       %s\n' "$script"
    else
        printf 'MISSING  %s (referenced by %s)\n' "$script" "$INSTALL_SH" >&2
        status=1
    fi
done <<<"$names"

if [ "$status" -ne 0 ]; then
    echo >&2
    echo "error: install.sh references setup scripts that do not exist" >&2
fi

exit "$status"
