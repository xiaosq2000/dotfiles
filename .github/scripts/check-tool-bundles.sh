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
import tomllib

machines = tomllib.load(open(".chezmoidata/machines.toml", "rb"))["machines"]
tools = tomllib.load(open(".chezmoidata/tools.toml", "rb"))
bundles = tools["bundles"]
overrides = tools.get("packages", {})

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

for w in warnings:
    print(f"warning  {w}", file=sys.stderr)
for e in errors:
    print(f"ERROR    {e}", file=sys.stderr)

if errors:
    print("\nerror: bundle data is inconsistent", file=sys.stderr)
    sys.exit(1)
PY
