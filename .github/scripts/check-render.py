#!/usr/bin/env python3
"""Render every machine and theme without downloads or installation, then check shell syntax."""

import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import tomllib

ROOT = Path(__file__).resolve().parents[2]
machines = tomllib.loads((ROOT / ".chezmoidata/machines.toml").read_text())["machines"]
mise_catalog = tomllib.loads((ROOT / ".chezmoidata/mise.toml").read_text())["mise"]
mise_lock = tomllib.loads((ROOT / "private_dot_config/mise/mise.lock").read_text())["tools"]
for tool_id, spec in mise_catalog.items():
    entries = [e for e in mise_lock.get(spec["tool"], []) if e.get("version") == spec["version"]]
    assert entries, f"mise.lock missing {tool_id} ({spec['tool']}@{spec['version']})"
    entry = entries[0]
    if "aube" in entry:
        lock_file = ROOT / "private_dot_config/mise" / entry["aube"]["path"] / "aube-lock.yaml"
        digest = "sha256:" + hashlib.sha256(lock_file.read_bytes()).hexdigest()
        assert digest == entry["aube"]["digest"], f"aube digest mismatch for {tool_id}"
    else:
        for platform in ("platforms.linux-x64", "platforms.linux-arm64"):
            assert entry.get(platform, {}).get("checksum", "").startswith("sha256:"), (
                f"mise.lock missing {platform} checksum for {tool_id}"
            )
themes = {}
for theme_file in sorted((ROOT / ".chezmoidata").glob("themes-*.toml")):
    themes.update(tomllib.loads(theme_file.read_text())["themes"])
modify_templates = sorted(
    path.relative_to(ROOT)
    for path in ROOT.rglob("modify_*.tmpl")
    if ".git" not in path.parts
)

with tempfile.TemporaryDirectory(prefix="dotfiles-render-") as temporary:
    home = Path(temporary)
    config = home / "chezmoi.toml"
    # An isolated home keeps the user's identity and configuration out of the test.
    environment = {"HOME": str(home), "PATH": os.environ["PATH"]}
    command = [
        "chezmoi", "--source", str(ROOT), "--destination", str(home),
        "--config", str(config), "--no-tty",
    ]
    subprocess.run(
        command + ["init", "--promptString", "machine=container",
                   "--promptString", "theme=rose-pine"],
        env=environment, check=True,
    )

    for machine in machines:
        print(f"Rendering machine={machine}", flush=True)
        rendered = subprocess.check_output(
            command + ["--override-data", json.dumps({"machine": machine}),
                       "dump", "--exclude", "externals", "--format", "json"],
            env=environment, text=True,
        )
        entries = json.loads(rendered)
        for _path, entry in entries.items():
            if entry["type"] == "script" and entry["contents"].strip():
                subprocess.run(["bash", "-n"], input=entry["contents"], text=True, check=True)
                subprocess.run(
                    ["shellcheck", "--severity=warning", "-"],
                    input=entry["contents"], text=True, check=True,
                )
        for name, shell in ((".bashrc", "bash"), (".zshenv", "zsh"), (".zshrc", "zsh")):
            subprocess.run(
                [shell, "-n"], input=entries[name]["contents"],
                text=True, check=True,
            )
        if ".config/mise/config.toml" in entries:
            tomllib.loads(entries[".config/mise/config.toml"]["contents"])
        else:
            assert machine == "container", f"unexpected missing mise config on {machine}"

    # Render every theme variant on the fullest machine and check modify_*.tmpl scripts.
    for theme in sorted(themes):
        print(f"Rendering theme={theme}", flush=True)
        override = json.dumps({"machine": "laptop", "theme": theme})
        subprocess.check_output(
            command + ["--override-data", override,
                       "dump", "--exclude", "externals", "--format", "json"],
            env=environment, text=True,
        )
        for template in modify_templates:
            rendered_script = subprocess.check_output(
                command + ["--override-data", override,
                           "execute-template", "--file", str(ROOT / template)],
                env=environment, text=True,
            )
            subprocess.run(["sh", "-n"], input=rendered_script, text=True, check=True)
            subprocess.run(
                ["shellcheck", "--severity=warning", "-"],
                input=rendered_script, text=True, check=True,
            )

print(
    f"All {len(machines)} machine profiles, {len(themes)} themes, "
    f"and {len(modify_templates)} modify templates rendered and passed shell checks."
)
