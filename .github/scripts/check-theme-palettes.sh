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
#
# It also holds each variant's zathura file to the variant's own colours. Those
# files are vendored per variant rather than fetched, so a copy of the wrong one
# renders without complaint and only looks wrong once that variant is selected.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

python3 - <<'PY'
import glob
import re
import sys
import tomllib

# Kept in step with the templates that read them. starship's roles are consumed
# by private_dot_config/starship.toml.tmpl, fzf's by dot_zshrc.tmpl.
STARSHIP_ROLES = ["surface", "error", "warn", "accent", "lang", "vcs", "primary"]
FZF_ROLES = ["fg", "bg", "hl", "fgPlus", "bgPlus", "hlPlus", "border",
             "header", "gutter", "spinner", "info", "pointer", "marker", "prompt"]
# Per-tool tokens every variant needs, plus the two structural fields.
TOKENS = ["scheme", "description", "appearance", "btop", "kitty", "kittyName",
          "alacritty", "nvim", "zathura", "herdr"]
SCHEME_KEYS = ["description", "btopURL", "kittyURL", "alacrittyURL",
               "nvimRepo", "nvimName"]
# The colours a zathura theme file must state for Ctrl+R to paint a page in the
# variant's own colours, and the `set <key> "#rrggbb"` lines that state them.
ZATHURA_DIR = "private_dot_config/zathura"
ZATHURA_KEYS = ["default-bg", "default-fg", "recolor-lightcolor", "recolor-darkcolor"]
ZATHURA_SET = re.compile(r'^set\s+(\S+)\s+"(#[0-9a-fA-F]{6})"', re.M)

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

    # fzf's bg is the variant's base colour, the page colour every tool shares,
    # so it is what the zathura file's own page colour has to equal. A missing
    # token or palette is already reported above, so skip those here.
    fzf = t.get("fzf")
    fzf_bg = fzf.get("bg") if isinstance(fzf, dict) else None
    if t.get("zathura") and isinstance(fzf_bg, str):
        zpath = f"{ZATHURA_DIR}/{t['zathura']}"
        try:
            with open(zpath, encoding="utf-8") as f:
                zset = {k: v.lower() for k, v in ZATHURA_SET.findall(f.read())}
        except OSError:
            errors.append(f"{where}: theme {slug}: zathura file {zpath} does not exist")
        else:
            missing = [k for k in ZATHURA_KEYS if k not in zset]
            for key in missing:
                errors.append(f'{zpath}: no `set {key} "#rrggbb"` line')
            if not missing:
                if zset["default-bg"] != fzf_bg.lower():
                    errors.append(f"{zpath}: default-bg is {zset['default-bg']}, but "
                                  f"{slug}'s base colour is {fzf_bg}; is it a copy of "
                                  f"another variant's file?")
                if zset["recolor-lightcolor"] != zset["default-bg"]:
                    errors.append(f"{zpath}: recolor-lightcolor is "
                                  f"{zset['recolor-lightcolor']} but default-bg is "
                                  f"{zset['default-bg']}, so Ctrl+R would paint pages "
                                  f"in a different colour from the window")
                if zset["recolor-darkcolor"] != zset["default-fg"]:
                    errors.append(f"{zpath}: recolor-darkcolor is "
                                  f"{zset['recolor-darkcolor']} but default-fg is "
                                  f"{zset['default-fg']}")

if errors:
    print("theme data is inconsistent:\n", file=sys.stderr)
    for e in errors:
        print(f"  {e}", file=sys.stderr)
    sys.exit(1)

print(f"{len(themes)} variants across {len(schemes)} schemes, all complete")
for slug in sorted(themes):
    print(f"  {slug} ({themes[slug]['appearance']})")
PY
