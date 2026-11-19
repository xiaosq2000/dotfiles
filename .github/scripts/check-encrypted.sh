#!/usr/bin/env bash
# Refuse plaintext anywhere this repository keeps secrets.
#
# The repository is public, so a secret committed in the clear is published by
# the next push, and CI only runs after that push. This check therefore runs as
# a pre-commit hook, which is what actually stops a leak, and again in CI, which
# catches a commit made with --no-verify or from a clone without the hooks.
#
# Every file under a protected directory has to pass two tests. The name must
# be encrypted_*.age, which catches `chezmoi add` without --encrypt: that writes
# private_imrl.md, in the clear, next to the ciphertext. The content must be
# age ciphertext, which catches a hand-made file that carries the right name
# around plaintext. The name alone would pass that one.
#
# It checks every file in the index, not the files pre-commit passes. The index
# is exactly what the next commit will contain, so this covers the commit being
# made, and in CI the index is the commit under test. It also sidesteps the
# top-level exclude in .pre-commit-config.yaml, which keeps every .age file away
# from the hooks and so would hide the very files the content test is for.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

# Source paths read from .chezmoidata/policy.toml [policy.repo].protected_source_dirs
# so every secret guard shares one source of truth.
PROTECTED=()
if command -v python3 >/dev/null 2>&1 && [ -f .chezmoidata/policy.toml ]; then
    while IFS= read -r entry; do
        [ -n "$entry" ] && PROTECTED+=("$entry")
    done < <(
        python3 - <<'PY'
from pathlib import Path
try:
    import tomllib
    data = tomllib.loads(Path(".chezmoidata/policy.toml").read_text(encoding="utf-8"))
    for item in data["policy"]["repo"]["protected_source_dirs"]:
        print(item)
except Exception:
    print("private_dot_ssh/")
    print("private_dot_agents/skills/private_machines/references/")
PY
    )
fi
if [ "${#PROTECTED[@]}" -eq 0 ]; then
    PROTECTED=(
        private_dot_ssh/
        private_dot_agents/skills/private_machines/references/
    )
fi

status=0
while IFS= read -r -d '' f; do
    for dir in "${PROTECTED[@]}"; do
        [[ $f == "$dir"* ]] || continue
        name=${f##*/}
        if [[ $name != encrypted_*.age ]]; then
            echo "$f: only encrypted_*.age files belong under $dir; use chezmoi add --encrypt" >&2
            status=1
            continue
        fi
        # Read the staged blob, not the working tree, since that is what gets
        # committed. `|| true` because head closing the pipe early is not an
        # error worth failing on.
        head=$(git cat-file blob ":$f" 2>/dev/null | head -c 34 || true)
        case "$head" in
            "-----BEGIN AGE ENCRYPTED FILE-----" | "age-encryption.org/v1"*) ;;
            *)
                echo "$f: named as ciphertext but does not start with an age header" >&2
                status=1
                ;;
        esac
    done
done < <(git ls-files -z)

if [ "$status" -ne 0 ]; then
    echo "Plaintext under a protected directory would be published by the next push. See docs/secrets.md." >&2
fi
exit "$status"
