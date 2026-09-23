#!/usr/bin/env bash
# Assert that .chezmoidata/machines.toml and .chezmoidata/tools.toml agree.
#
# The pixi global manifest is rendered from those two files, and `pixi global
# sync` then makes a machine match it exactly. That makes a typo expensive in a
# specific way: a machine naming a bundle that does not exist, or a bundle
# naming a package that is never exposed, does not fail loudly. It produces a
# machine that quietly lacks a tool, and the machines that would notice are
# usually the ones nobody applies to first.
#
# These are consistency checks over the data, not over conda-forge. Whether a
# package exists, and whether it really ships the binaries `exposed` claims, is
# only answerable by solving the environment, which belongs in a slower job than
# one that gates every push. An inaccurate name there fails the sync with a
# clear message.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

python3 - <<'PY'
import sys
import re
from pathlib import PurePosixPath
import tomllib

machines = tomllib.load(open(".chezmoidata/machines.toml", "rb"))["machines"]
tools = tomllib.load(open(".chezmoidata/tools.toml", "rb"))
bundles = tools["bundles"]
overrides = tools.get("packages", {})
downloads = tomllib.load(open(".chezmoidata/downloads.toml", "rb"))["downloads"]

errors = []
warnings = []

# 1. Every bundle a machine selects has to exist.
for name, m in sorted(machines.items()):
    for bundle in m.get("bundles", []):
        if bundle not in bundles:
            errors.append(
                f"machine {name!r} selects bundle {bundle!r}, "
                "which is not in tools.toml"
            )

# 2. Every bundle has to be reachable from some machine, or it is dead data
#    that reads like a live option.
used = {b for m in machines.values() for b in m.get("bundles", [])}
for bundle in sorted(set(bundles) - used):
    warnings.append(f"bundle {bundle!r} is selected by no machine")

# 3. Every exposure override has to name a package some bundle contains, and
#    has to expose at least one binary. An empty list would install the
#    environment and link nothing.
in_bundles = {p for b in bundles.values() for p in b["packages"]}
for pkg, spec in sorted(overrides.items()):
    if pkg not in in_bundles:
        errors.append(
            f"packages.{pkg} has an exposure override but no bundle contains it"
        )
    exposed = spec.get("exposed")
    if not exposed:
        errors.append(f"packages.{pkg} exposes nothing")
    elif len(set(exposed)) != len(exposed):
        errors.append(f"packages.{pkg} lists a binary twice: {exposed}")

# 4. A package in two bundles renders one environment, so it works, but
#    removing either bundle no longer removes the tool.
for pkg in sorted(in_bundles):
    holders = sorted(n for n, b in bundles.items() if pkg in b["packages"])
    if len(holders) > 1:
        warnings.append(f"{pkg!r} is in more than one bundle: {', '.join(holders)}")

# 5. Two packages exposing the same binary name would race for the same link
#    in ~/.pixi/bin, and which one wins depends on solve order.
for name, m in sorted(machines.items()):
    selected = [p for b in m.get("bundles", []) if b in bundles
                for p in bundles[b]["packages"]]
    owner = {}
    for pkg in dict.fromkeys(selected):
        for binary in overrides.get(pkg, {}).get("exposed", [pkg]):
            if binary in owner and owner[binary] != pkg:
                errors.append(
                    f"on machine {name!r}, {pkg!r} and {owner[binary]!r} both "
                    f"expose {binary!r}"
                )
            owner[binary] = pkg
    print(f"ok       {name}: {len(set(selected))} packages, {len(owner)} binaries")

# 6. Downloads. dotfiles-fetch trusts this catalog, so a bad entry should fail
#    here rather than on a machine halfway through a sync.
platforms = {"linux-amd64", "linux-arm64", "darwin-amd64", "darwin-arm64"}
commands = {}
for name, spec in sorted(downloads.items()):
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", name):
        errors.append(f"download {name!r}: ids are lowercase words joined by hyphens")
    unknown = set(spec) - {"github", "asset", "file", "url", "strip", "bin", "fonts", "write", "copy"}
    if unknown:
        errors.append(f"download {name!r}: unknown fields {sorted(unknown)}")
    kinds = [k for k in ("asset", "file", "url") if k in spec]
    if len(kinds) != 1 or (kinds[0] == "url") == ("github" in spec):
        errors.append(f"download {name!r}: needs url, or github with one of asset and file")
    for kind in kinds:
        value = spec[kind]
        if isinstance(value, dict) and (not value or set(value) - platforms):
            errors.append(f"download {name!r}: {kind} is keyed by {sorted(value)}, not by {sorted(platforms)}")
    if not any(k in spec for k in ("bin", "fonts", "copy")):
        errors.append(f"download {name!r}: installs nothing visible; give it bin, fonts or copy")
    if "fonts" in spec and any(k in spec for k in ("bin", "write", "copy", "strip")):
        errors.append(f"download {name!r}: a font download takes only fonts")
    paths = list(spec.get("bin", [])) + list(spec.get("write", {})) + list(spec.get("copy", {}))
    paths += list(spec.get("copy", {}).values())
    for path in paths:
        parts = PurePosixPath(path).parts
        if not parts or PurePosixPath(path).is_absolute() or ".." in parts:
            errors.append(f"download {name!r}: unsafe path {path!r}")
    for command in spec.get("bin", []):
        base = PurePosixPath(command).name
        if base in commands:
            errors.append(f"downloads {commands[base]!r} and {name!r} both provide {base!r}")
        commands[base] = name
for name, bundle in sorted(bundles.items()):
    for download in bundle.get("downloads", []):
        if download not in downloads:
            errors.append(f"bundle {name!r} selects download {download!r}, which is not in downloads.toml")
    for path in bundle.get("config", []):
        parts = PurePosixPath(path).parts
        if len(parts) < 2 or PurePosixPath(path).is_absolute() or ".." in parts:
            errors.append(f"bundle {name!r}: config path {path!r} is not a specific file or directory")
selected_downloads = {d for b in bundles.values() for d in b.get("downloads", [])}
for name in sorted(set(downloads) - selected_downloads):
    warnings.append(f"download {name!r} is selected by no bundle")
for name, machine in sorted(machines.items()):
    for obsolete in ["desktop", "typefaces", "rust"]:
        if obsolete in machine:
            errors.append(f"machine {name!r}: {obsolete} is a bundle now, not a machine field")

for w in warnings:
    print(f"warning  {w}", file=sys.stderr)
for error in errors:
    print(f"ERROR    {error}", file=sys.stderr)

if errors:
    print("\nerror: bundle data is inconsistent", file=sys.stderr)
    sys.exit(1)
PY
