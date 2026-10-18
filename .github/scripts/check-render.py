#!/usr/bin/env python3
"""Render each machine without downloads or installation, then check shell syntax."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import tomllib

ROOT = Path(__file__).resolve().parents[2]
machines = tomllib.loads((ROOT / ".chezmoidata/machines.toml").read_text())["machines"]

with tempfile.TemporaryDirectory(prefix="dotfiles-render-") as temporary:
    home = Path(temporary)
    config = home / "chezmoi.toml"
    # An isolated home keeps the user's identity and configuration out of the test.
    environment = {"HOME": str(home), "PATH": os.environ["PATH"]}
    command = ["chezmoi", "--source", str(ROOT), "--destination", str(home),
               "--config", str(config), "--no-tty"]
    subprocess.run(command + ["init", "--promptString", "machine=container",
                              "--promptString", "theme=rose-pine"],
                   env=environment, check=True)

    for machine in machines:
        print(f"Rendering {machine}", flush=True)
        rendered = subprocess.check_output(
            command + ["--override-data", json.dumps({"machine": machine}),
                       "dump", "--exclude", "externals", "--format", "json"],
            env=environment, text=True)
        entries = json.loads(rendered)
        for path, entry in entries.items():
            if entry["type"] == "script":
                subprocess.run(["bash", "-n"], input=entry["contents"], text=True, check=True)
                subprocess.run(["shellcheck", "--severity=warning", "-"],
                               input=entry["contents"], text=True, check=True)
        for shell in ("bash", "zsh"):
            subprocess.run([shell, "-n"], input=entries[f".{shell}rc"]["contents"],
                           text=True, check=True)

print("All machine configurations render and shell syntax checks pass.")
