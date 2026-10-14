#!/usr/bin/env python3
"""Check optional TeX Live selection and inherited PATH priority in zsh."""

from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
zshrc = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "dot_zshrc.tmpl"
basics = Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / "dot_sh_utils/basics.sh"
zsh = shutil.which("zsh")
assert zsh, "zsh is required"


def function(path, name):
    match = re.search(rf"^{name}\(\) \{{\n.*?^\}}", path.read_text(), re.M | re.S)
    assert match, f"{name} is missing from {path}"
    return match.group()


setup = function(zshrc, "setup_texlive")
assert setup + "\nsetup_texlive\n" in zshrc.read_text(), "TeX setup is not called"
helpers = "\n".join(function(basics, name) for name in
                    ("append_env", "remove_from_env", "prepend_env"))
payload = helpers + "\n" + setup + r'''
debug() { :; }
hint() { print -u2 -- "$*"; }
# A pixi zsh launcher can change PATH before this script starts.
export PATH="$TEX_TEST_PATH"
# Completion and plugins can populate the command hash before TeX selection.
hash -f
setup_texlive
print -r -- "$PATH"
setup_texlive
print -r -- "$PATH"
# Plugins read this special array, which populates zsh's command hash.
: "${commands[l3build]}" "${commands[texlua]}" "${commands[kpsewhich]}"
for tool in l3build texlua kpsewhich; do
    command -v "$tool"
done
l3build --version
'''

# Each installation provides an interpreter. l3build uses env, as upstream does.
# A system interpreter prints a different marker if PATH mixes the installations.
cases = [
    ("absent", [], [], None, False),
    ("unsupported architecture", [(2026, "aarch64-linux")], [], None, False),
    ("nonnumeric directory", [("current", "x86_64-linux")], [], None, False),
    ("user latest", [(2025, "x86_64-linux"), (2026, "x86_64-linux")],
     [(2024, "x86_64-linux")], ("user", 2026), False),
    ("inherited user entry", [(2026, "x86_64-linux")], [], ("user", 2026), True),
    ("inherited canonical entry", [(2026, "x86_64-linux")], [],
     ("user", 2026), "canonical"),
    ("both inherited forms", [(2026, "x86_64-linux")], [], ("user", 2026), "both"),
    ("system latest", [(2026, "x86_64-linux")], [(2027, "x86_64-linux")],
     ("system", 2027), False),
    ("inherited system entry", [], [(2026, "x86_64-linux")],
     ("system", 2026), True),
    ("equal versions prefer user", [(2026, "x86_64-linux")],
     [(2026, "x86_64-linux")], ("user", 2026), False),
    ("numeric version order", [(9, "x86_64-linux"), (10, "x86_64-linux")], [],
     ("user", 10), False),
]

with tempfile.TemporaryDirectory(prefix="check-texlive-path-") as temporary:
    for number, (name, users, systems, selected, inherited) in enumerate(cases):
        base = Path(temporary) / str(number)
        data = base / "relocated/share"
        data.mkdir(parents=True)
        prefix = base / "prefix"
        fallback = base / "system-bin"
        fallback.mkdir()
        roots = {"user": str(data) + "/../texlive", "system": str(prefix / "texlive")}

        def install(directory, marker):
            directory = Path(directory)
            directory.mkdir(parents=True, exist_ok=True)
            for tool in ("l3build", "texlua", "kpsewhich"):
                stub = directory / tool
                stub.write_text("#!/usr/bin/env texlua\n" if tool == "l3build" else
                                f"#!/bin/sh\nprintf '%s\\n' '{marker}'\n")
                stub.chmod(0o755)

        install(fallback, "system interpreter")
        for root, versions in ((roots["user"], users), (roots["system"], systems)):
            for version, architecture in versions:
                install(f"{root}/{version}/bin/{architecture}", f"TeX Live {version}")

        chosen = f"{roots[selected[0]]}/{selected[1]}" if selected else None
        raw_binary = f"{chosen}/bin/x86_64-linux" if chosen else str(fallback)
        binary = str(Path(raw_binary).resolve())
        original = f"{fallback}:/usr/bin:/bin"
        if inherited:
            original += ":" + (binary if inherited == "canonical" else raw_binary)
            if inherited == "both":
                original += ":" + binary
        environment = {
            "HOME": str(base), "PATH": original, "TEX_TEST_PATH": original,
            "LC_ALL": "C.UTF-8", "XDG_DATA_HOME": str(data),
            "XDG_PREFIX_DIR": str(prefix),
        }
        result = subprocess.run([zsh, "-dfc", payload], env=environment,
                                text=True, capture_output=True, timeout=10, check=True)
        assert not result.stderr, (name, result.stderr)
        lines = result.stdout.splitlines()
        expected_path = original
        if chosen:
            expected_path = binary + ":" + f"{fallback}:/usr/bin:/bin"
            if selected[0] == "system":
                expected_path += f":{chosen}/texmf-dist/doc/info:{chosen}/texmf-dist/doc/man"
        assert lines[:2] == [expected_path, expected_path], (name, lines[:2])
        assert lines[2:5] == [f"{binary}/{tool}" for tool in
                              ("l3build", "texlua", "kpsewhich")], (name, lines)
        expected_version = f"TeX Live {selected[1]}" if selected else "system interpreter"
        assert lines[5:] == [expected_version], (name, lines)
        print(f"TeX PATH: {name} passed")

print(f"{len(cases)} TeX Live selection, interpreter and idempotence checks passed.")
