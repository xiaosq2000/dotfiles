#!/usr/bin/env bash
# Assert that every theme variant can actually be rendered.
#
# A variant is data spread across one [themes.<slug>] table and two palettes,
# and nothing at apply time checks that the set is complete. A missing key is
# not a loud failure: `index` on an absent map entry renders the empty string,
# so a half-filled palette produces a starship config whose colours are `""`
# and an fzf palette with holes. starship then falls back to its defaults for
# the affected modules, which looks like a theme that is merely a bit off
# rather than one that is broken.
#
# That is worth a gate precisely because adding a scheme is meant to be "add a
# file and edit nothing". This is the check that makes the promise safe: if the
# new file is missing a role, CI says which slug and which key.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

python3 - <<'PY'
import glob
import sys
import tomllib

# Kept in step with the templates that read them. starship's roles are consumed
# by private_dot_config/starship.toml.tmpl, fzf's by dot_zshrc.tmpl.
STARSHIP_ROLES = ["surface", "error", "warn", "accent", "lang", "vcs", "primary"]
FZF_ROLES = ["fg", "bg", "hl", "fgPlus", "bgPlus", "hlPlus", "border",
             "header", "gutter", "spinner", "info", "pointer", "marker", "prompt"]
# Per-tool tokens every variant needs, plus the two structural fields.
TOKENS = ["scheme", "description", "appearance", "btop", "kitty", "kittyName",
          "alacritty", "nvim", "zathura"]
SCHEME_KEYS = ["description", "btopURL", "kittyURL", "alacrittyURL",
               "nvimRepo", "nvimName"]

schemes, themes, origin = {}, {}, {}
for path in sorted(glob.glob(".chezmoidata/themes-*.toml")):
    data = tomllib.load(open(path, "rb"))
    schemes.update(data.get("schemes", {}))
    for slug, t in data.get("themes", {}).items():
        themes[slug] = t
        origin[slug] = path

errors = []

if not themes:
    errors.append("no [themes.*] found in .chezmoidata/themes-*.toml")

for name, s in sorted(schemes.items()):
    for key in SCHEME_KEYS:
        if not s.get(key):
            errors.append(f"scheme {name}: missing {key}")
    # starshipDir was removed when the prompt became a template. A scheme file
    # still carrying it is a copy of the old shape and its author probably
    # expects a checkout that no longer happens.
    if "starshipDir" in s:
        errors.append(f"scheme {name}: starshipDir is obsolete; starship is "
                      f"rendered from [themes.<slug>.starship] now")

for slug, t in sorted(themes.items()):
    where = origin[slug]
    for key in TOKENS:
        if not t.get(key):
            errors.append(f"{where}: theme {slug}: missing {key}")
    if t.get("scheme") not in schemes:
        errors.append(f"{where}: theme {slug}: unknown scheme {t.get('scheme')!r}")
    if t.get("appearance") not in ("light", "dark"):
        errors.append(f"{where}: theme {slug}: appearance must be light or dark, "
                      f"got {t.get('appearance')!r}")
    for table, roles in (("starship", STARSHIP_ROLES), ("fzf", FZF_ROLES)):
        pal = t.get(table)
        if not isinstance(pal, dict):
            errors.append(f"{where}: theme {slug}: missing [{table}] palette")
            continue
        for role in roles:
            v = pal.get(role)
            if not isinstance(v, str) or not v.startswith("#") or len(v) != 7:
                errors.append(f"{where}: theme {slug}: {table}.{role} must be "
                              f"a #rrggbb colour, got {v!r}")
        for extra in sorted(set(pal) - set(roles)):
            errors.append(f"{where}: theme {slug}: {table}.{extra} is not a role "
                          f"any template reads")

if errors:
    print("theme data is inconsistent:\n", file=sys.stderr)
    for e in errors:
        print(f"  {e}", file=sys.stderr)
    sys.exit(1)

print(f"{len(themes)} variants across {len(schemes)} schemes, all complete")
for slug in sorted(themes):
    print(f"  {slug} ({themes[slug]['appearance']})")
PY
